# 03 · Spark 关联规则分析

对应 `slides/第3章-3.4项目实践.pptx` §3.4.2 与 `reports/` 实训报告06。

目标：用 **PySpark + FPGrowth** 挖掘「买了 A 的顾客往往也买 B」这类商品组合规律，并把关联规则回写到 MySQL 供可视化页面读取。

## 1. 环境配置

### 1.1 MySQL JDBC 驱动

PySpark 通过 JDBC 读写 MySQL，需要驱动在 JVM 的扩展路径下：

```bash
cd /usr/local/hive/lib
sudo cp mysql-connector-java-5.1.40-bin.jar $JAVA_HOME/jre/lib/ext
```

### 1.2 Python 虚拟环境

系统 Python 3.10 与 Spark 2.4.0 不兼容，用 conda 建 3.6.9：

```bash
conda create -n spark24 python=3.6.9 -y
conda activate spark24
pip install numpy
```

### 1.3 启动服务

```bash
sudo service mysql start
cd /usr/local/hadoop/
sbin/start-dfs.sh

# 按课件路径重新上传一份数据
./bin/hdfs dfs -mkdir -p /dbjd/dataset
./bin/hdfs dfs -put ~/data/MarketSales_transform1.csv /dbjd/dataset
```

> **路径说明**：数据存储阶段（见 `02-数据存储与传输.md`）用的是 `/supermarket/dataset/user_log`，本阶段课件改用 `/dbjd/dataset`。两者等价，统一任一路径即可，但要同步改脚本里的 `PATH_CSV` 常量。

### 1.4 启动 PySpark

```bash
cd /usr/local/spark
./bin/pyspark
```

## 2. 数据读取与预处理

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import collect_set

spark = SparkSession.builder.appName("retail-fpgrowth").getOrCreate()

# 课件写法（需 spark-csv 依赖）
# df = spark.read.format('com.databricks.spark.csv') \
#         .options(header='true', inferschema='true') \
#         .load('/dbjd/dataset/MarketSales_transform1.csv')

# Spark 2.4 内置 CSV 支持，推荐写法
df = spark.read.csv('/dbjd/dataset/MarketSales_transform1.csv',
                    header=True, inferSchema=True)
```

### 2.1 查看数据概况

```python
df.printSchema()
df.show()
df.show(truncate=False)      # 展开折叠字段
df.describe().show()
```

### 2.2 清洗脏数据

关联分析只依赖 **会员卡号 `FICHENO`** 与 **商品编号 `ITEMCODE`**，两列为空则无法构成有用组合，需剔除。

```python
# 去掉没有会员卡号的记录
clean = df.filter(df["FICHENO"].isNotNull())
clean.count()

# 再去掉没有商品编号的记录
clean = clean.filter(clean["ITEMCODE"].isNotNull())
clean.count()
```

> ⚠️ **课件原代码有缺陷**：第二行为 `clean = clean.filter(df["ITEMCODE"].isNotNull())`，引用的是旧的 `df` 而非 `clean`，导致上一步对 `FICHENO` 的过滤结果被丢弃。此处已改为 `clean["ITEMCODE"]`。

## 3. FPGrowth 关联分析

### 3.1 构造「每人购买商品集合」

```python
data = clean.groupBy("FICHENO") \
            .agg(collect_set("ITEMCODE")) \
            .withColumnRenamed("collect_set(ITEMCODE)", "ITEM_LIST")

data.count()
```

此时每行代表一位会员，`ITEM_LIST` 是其购买过的全部商品编号数组——正是 FPGrowth 需要的输入格式。

### 3.2 第一轮训练

```python
from pyspark.ml.fpm import FPGrowth

fpGrowth = FPGrowth(itemsCol="ITEM_LIST",
                    minSupport=0.01,
                    minConfidence=0.1)
model = fpGrowth.fit(data)
```

| 参数 | 含义 | 第一轮取值 |
|---|---|---|
| `minSupport` | 最小支持度：项集出现频率下限 | 0.01 |
| `minConfidence` | 最小置信度：规则可靠性下限 | 0.1 |

查看结果：

```python
model.freqItemsets.show()          # 频繁项集
model.associationRules.show()      # 关联规则
```

### 3.3 查商品名称

规则里只有商品编号，需要回原始数据查名称确认业务含义：

```python
df.where("ITEMCODE = 5715").show()
df.where("ITEMCODE = 5716").show()
```

### 3.4 第二轮训练（调参对比）

支持度放宽、置信度收紧：

```python
fpGrowth = FPGrowth(itemsCol="ITEM_LIST",
                    minSupport=0.005,
                    minConfidence=0.2)
model = fpGrowth.fit(data)

model.associationRules.show()
```

两轮对比结论：

| 轮次 | minSupport | minConfidence | 结果特征 |
|---|---|---|---|
| 第一轮 | 0.01 | 0.1 | 规则数量少，聚焦高频商品组合 |
| 第二轮 | 0.005 | 0.2 | 支持度门槛降低使候选变多，置信度提高保证可靠性，规则更丰富且更可信 |

> 支持度调低会显著增加计算量，61 万行数据在单机伪分布式下可接受，但再低（如 0.001）需注意内存。

## 4. 结果写入 MySQL

### 4.1 Array 列转 String

`associationRules` 的 `antecedent` / `consequent` 是数组类型，MySQL 无对应类型，需取首个元素并转字符串：

```python
rules = model.associationRules
rules.printSchema()

rules1 = rules.withColumn("consequent",
                          rules["consequent"].getItem(0).cast("string"))
rules1.printSchema()
rules1.show()

rules2 = rules1.withColumn("antecedent",
                           rules1["antecedent"].getItem(0).cast("string"))
```

### 4.2 建表

```sql
use supermarket;
create table rules (
    antecedent varchar(100),
    consequent varchar(100),
    confidence double,
    lift       double
) engine=InnoDB default charset=utf8;
```

### 4.3 通过 JDBC 写入

```python
rules2.write.format('jdbc').options(
    url='jdbc:mysql://localhost:3306/supermarket?useUnicode=true&characterEncoding=utf8',
    useSSL="false",
    driver='com.mysql.jdbc.Driver',
    dbtable='rules',
    user='root',
    password='123456'
).mode('append').save()
```

校验：

```sql
use supermarket;
show tables;        -- 应出现 rules
select * from rules;
```

### 4.4 导出 CSV 供可视化使用

```sql
show variables like "secure_file_priv";
```

```sql
select * from (
    select 'antecedent','consequent','confidence','lift'
    union all
    select antecedent, consequent, confidence, lift from rules
) b
into outfile '/var/lib/mysql-files/rules.csv'
fields terminated by ',' lines terminated by '\n';
```

```bash
sudo cp /var/lib/mysql-files/rules.csv /home/hadoop/data/
sudo chown 777 /home/hadoop/data/rules.csv
```

## 5. 运行完整脚本

`code/spark/fpgrowth_analysis.py` 已把上述步骤整合为可直接提交的脚本：

```bash
cd /usr/local/spark
conda activate spark24
./bin/spark-submit \
  --master local[*] \
  --jars /usr/local/hive/lib/mysql-connector-java-5.1.40-bin.jar \
  ~/hive-spark-retail-analysis/code/spark/fpgrowth_analysis.py
```

脚本会依次完成：读取 → 清洗 → 分组 → 两轮 FPGrowth → 写 MySQL `rules` 表 → 控制台打印摘要。

## 关联规则结果解读

`model.associationRules` 返回四列：

| 列 | 含义 |
|---|---|
| `antecedent` | 前项，顾客已购买的商品数组 |
| `consequent` | 后项，被连带购买的商品数组 |
| `confidence` | 置信度：买了前项的人里有多大比例也买了后项 |
| `lift` | 提升度：>1 表示正相关，=1 表示独立，<1 表示负相关 |

关系图（页面5）展示的就是 `antecedent → consequent`，线宽可用 `confidence` 或 `lift` 映射，便于直观看出强关联组合。
