# 基于 Hive + MySQL + Spark 的零售交易数据离线分析

对土耳其零售商超的交易数据（**611,108 条**记录、**26** 个字段）做离线统计分析与商品关联规则挖掘，并把结果通过 ECharts 做可视化展示。

完整链路：**CSV 转码 → HDFS → Hive 外部表 → Hive SQL 统计 → Sqoop 导出到 MySQL → MySQL 清洗 → PySpark FPGrowth 关联分析 → JDBC 回写 MySQL → 导出 CSV → ECharts 可视化**。

## 数据集

| 项 | 内容 |
|---|---|
| 文件 | `MarketSales_edit.csv`（另附 `data/3.4数据集.rar`，13.5 MB 压缩包） |
| 规模 | 611,108 行 × 26 列，约 139 MB |
| 来源 | 土耳其 81 个超市门店 2017 年 1~3 月交易记录，人造数据集 |
| 覆盖 | 52,000+ 会员顾客、9,000+ 商品、会员卡号、商品三级分类、品牌、城市与经纬度 |

字段说明：

| 字段 | 含义 | 字段 | 含义 |
|---|---|---|---|
| ID | 数据 ID | REGION | 门店所属八大区域 |
| ITEMCODE | 商品编号 | LATITUDE | 纬度 |
| ITEMNAME | 商品名称 | LONGTITUDE | 经度 |
| FICHENO | 会员卡号 | CLIENTCODE | 收银台编号 |
| DATE_ | 日期 | BRANDCODE | 品牌编号 |
| AMOUNT | 数量 | BRAND | 品牌 |
| PRICE | 单价 | category_NAME1 | 商品一级分类 |
| LINENETTOTAL | 总价 | category_NAME2 | 商品二级分类 |
| LINENET | 优惠价格 | category_NAME3 | 商品三级分类 |
| BRANCHNR | 分店编号 | STARTDATE | 收银开始时间 |
| BRANCH | 分店 | ENDDATA | 收银结束时间 |
| SALESMAN | 售货员 | GMALENDMALER | 会员性别 |
| CITY | 分店所在城市 | | |

## 技术栈

| 组件 | 版本 | 用途 |
|---|---|---|
| Hadoop | 2.7.1（伪分布式） | HDFS 分布式存储 |
| Hive | 1.2.1 | 数据仓库，外部表关联 HDFS |
| MySQL | 5.7.16 | Hive 元数据库 + 分析结果落库 |
| Sqoop | 1.4.6 | Hive ↔ MySQL 数据传输 |
| Spark | 2.4.0 | PySpark，FPGrowth 关联规则挖掘 |
| JDK | 1.8.0_162 | 运行环境 |
| Eclipse + Tomcat | 2022-09 / 8.5.100 | ECharts 可视化 Web 应用 |
| ECharts | — | 图表渲染 |

## 目录结构

```
hive-spark-retail-analysis/
├── README.md
├── docs/
│   ├── 01-环境部署.md            # Hadoop/Hive/MySQL/Sqoop/Spark 安装与配置
│   ├── 02-数据存储与传输.md       # HDFS 上传、Hive 建表查询、Sqoop 导出、清洗
│   ├── 03-Spark关联分析.md       # PySpark FPGrowth 挖掘与结果落库
│   └── 04-ECharts可视化.md       # Java Web + ECharts 五个页面
├── code/
│   ├── hive/                    # 建库建表与统计查询 SQL
│   ├── mysql/                   # 建表、清洗、导出 SQL
│   ├── sqoop/                   # Hive → MySQL 导出脚本
│   └── spark/                   # PySpark FPGrowth 完整脚本
├── data/
│   └── 3.4数据集.rar             # 原始数据集压缩包
├── reports/                     # 实训报告 04/05/06（含逐步截图）
├── slides/                      # 课程 PPT：3.2 环境部署、3.4 项目实践
└── screenshots/
    ├── 环境部署/                 # 49 张，对应实训报告04
    └── 数据分析/                 # 69 张，对应实训报告05/06
```

## 分析流程

```
MarketSales_edit.csv (GBK, 139MB)
        │  iconv 转 UTF-8 + 删表头
        ▼
MarketSales_transform1.csv
        │  hdfs dfs -put
        ▼
HDFS: /supermarket/dataset/user_log
        │  外部表映射
        ▼
Hive: supermarket.user_log (26 字段)
        │  ① Hive SQL 统计：总量/大类/会员数/二级分类
        │  ② INSERT OVERWRITE → inner_user_log
        ▼
Sqoop export ──► MySQL: supermarket.user_log
        │  删除 city/category_I/category_II/sex 空值行
        │  导出清洗后 CSV（带表头）
        ▼
PySpark: 读 HDFS → 过滤空 FICHENO/ITEMCODE → groupBy + collect_set
        │  FPGrowth(minSupport, minConfidence) 两轮调参
        ▼
关联规则 DataFrame ──JDBC──► MySQL: supermarket.rules
        │
        ▼
ECharts 五页面（饼图 ×2 / 柱状图 / 气泡图 / 关系图）
```

## 快速开始

前置：Ubuntu 18.04，按 [docs/01-环境部署.md](docs/01-环境部署.md) 装好 Hadoop / Hive / MySQL / Sqoop / Spark，全程在 `hadoop` 用户下操作。

```bash
# 1. 准备数据
unrar x data/3.4数据集.rar            # 得到 MarketSales_edit.csv
cd ~/data
iconv -f gbk -t utf8 MarketSales_edit.csv > MarketSales_transform1.csv
sed -i '1d' MarketSales_transform1.csv      # 删除表头行

# 2. 上传 HDFS
/usr/local/hadoop/sbin/start-all.sh
cd /usr/local/hadoop
./bin/hdfs dfs -mkdir -p /supermarket/dataset/user_log
./bin/hdfs dfs -put ~/data/MarketSales_transform1.csv /supermarket/dataset/user_log

# 3. Hive 建库建表并统计
hive -f code/hive/01-create-external-table.sql
hive -f code/hive/02-analysis-queries.sql
hive -f code/hive/03-inner-table.sql

# 4. MySQL 建表 + Sqoop 导出
mysql -uroot -p123456 < code/mysql/01-create-tables.sql
bash code/sqoop/export-hive-to-mysql.sh
mysql -uroot -p123456 < code/mysql/02-clean-and-export.sql

# 5. PySpark 关联分析
cd /usr/local/spark
./bin/spark-submit ~/hive-spark-retail-analysis/code/spark/fpgrowth_analysis.py
```

## 关键结果

| 分析项 | 方法 | 呈现形式 |
|---|---|---|
| 商品大类成交量分布 | `group by category_I` | 饼图（页面1） |
| 饮品二级分类占比 | `where category_I='DRINK'` 后按 `category_II` 分组 | 饼图（页面2） |
| 各省会员分布 | 按 `city` 统计 `count(distinct ficheno)` + 经纬度 | 气泡图（页面3） |
| 男女会员购买对比 | 按 `sex` × `category_I` 交叉统计 | 柱状图（页面4） |
| 商品关联规则 | FPGrowth(minSupport=0.005, minConfidence=0.2) | 关系图（页面5） |

关联规则两轮参数对比：

| 参数 | minSupport | minConfidence | 效果 |
|---|---|---|---|
| 第一轮 | 0.01 | 0.1 | 规则较少，覆盖高频组合 |
| 第二轮 | 0.005 | 0.2 | 支持度放宽、置信度收紧，规则数量增加且更可靠 |

## 说明与已知问题

- **数据集**：原始 CSV 约 139 MB，超过 GitHub 单文件 100 MB 限制，因此仓库内提供的是 13.5 MB 压缩包，使用前需解压。
- **HDFS 路径不一致**：数据存储阶段使用 `/supermarket/dataset/user_log`，而 Spark 阶段按课件重新上传至 `/dbjd/dataset`。两处均已保留并标注，复现时统一为任一即可，只需同步修改脚本中的路径。
- **课件代码缺陷已修正**：原课件中 `clean = clean.filter(df["ITEMCODE"].isNotNull())` 引用了旧的 `df`，会导致上一行对 `FICHENO` 的过滤结果被丢弃。仓库脚本已改为对 `clean` 连续过滤，并在注释中标明。
- **CSV 读取方式**：课件使用 `format('com.databricks.spark.csv')`，需额外 spark-csv 依赖；Spark 2.4 已内置 CSV 支持，脚本中改用 `spark.read.csv`。
- **中文表头导出**：`into outfile` 的路径受 MySQL `secure_file_priv` 限制，本环境为 `/var/lib/mysql-files/`，导出后需复制到 `~/data` 并改权限。
