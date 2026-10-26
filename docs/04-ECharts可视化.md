# 04 · ECharts 可视化

对应 `slides/第3章-3.4项目实践.pptx` §3.4.3。

把前面落到 MySQL 的分析结果做成 5 个可视化页面，用 **Java Web（Servlet + JSP）+ ECharts** 实现。

## 1. 程序架构

```
可视化工程/
├── src/                  Java 源代码，connDb.java 负责连 MySQL 并产出各页面数据
├── WebContent/           前端页面，5 个 JSP 对应 5 个页面
│   ├── index.jsp         页面骨架与数据绑定
│   ├── index_1.jsp       页面2
│   ├── index_2.jsp       页面3
│   ├── ...
│   ├── css/style.css     布局与配色
│   └── js/               ECharts、macarons.js 等主题与图表脚本
└── lib/                  JDBC 驱动（mysql-connector-java-5.1.40-bin.jar）
```

- `connDb.java`：连接 MySQL 的 `supermarket` 库，为每个页面提供查询结果
- `index.jsp`：页面布局 + 通过 JSP 关联 `connDb.java` 中对应的 `index()` 方法取数
- 配色：侧边栏与主体统一使用 ECharts 的 `macarons` 主题配色

## 2. 数据库连接

`connDb.java` 连接参数：

```java
String url = "jdbc:mysql://localhost:3306/supermarket?useUnicode=true&characterEncoding=utf8";
String user = "root";
String password = "123456";
Class.forName("com.mysql.jdbc.Driver");
Connection conn = DriverManager.getConnection(url, user, password);
```

> 调试技巧：在方法里加 `System.out.println(temp[0] + ":" + temp[1])` 把查询结果打到控制台，便于确认 SQL 写对后再交给前端。

## 3. 五个页面与对应查询

| 页面 | 图表类型 | 数据来源 | 核心 SQL |
|---|---|---|---|
| 1 | 饼图 | 超市各类商品成交量对比 | `select category_I, count(*) num from user_log group by category_I` |
| 2 | 饼图 | 饮品（DRINK）下各二级分类成交量 | `select category_II, count(*) num from user_log where category_I='DRINK' group by category_II` |
| 3 | 气泡图 | 各省会员人数 + 经纬度定位 | `select city, count(distinct ficheno) num, latitude, longitude from user_log group by city, latitude, longitude` |
| 4 | 柱状图 | 男女会员在各商品大类下的购买量 | `select sex, category_I, count(*) num from user_log group by sex, category_I` |
| 5 | 关系图 | 商品关联规则（来自 `rules` 表） | `select antecedent, consequent, confidence, lift from rules` |

### 3.1 页面 1 —— 商品大类成交量饼图

对应 `connDb` 的 `index()` 方法。用 `category_I` 分组统计成交量，饼图直观展示各品类占比。

### 3.2 页面 2 —— 饮品二级分类饼图

对应 `index_1()`。在 `category_I='DRINK'` 条件下按 `category_II` 分组，看饮料内部细分的销量结构。

### 3.3 页面 3 —— 各省会员分布气泡图

对应 `index_2()`。气泡的横纵坐标来自 `longitude` / `latitude`，气泡大小映射该省会员人数，实现地理维度上的分布可视化。

### 3.4 页面 4 —— 男女购买对比柱状图

按 `sex` × `category_I` 交叉统计，双系列柱状图对比男女会员在不同品类的购买偏好。

### 3.5 页面 5 —— 商品关联关系图

读取 `rules` 表，ECharts `graph` 类型渲染 `antecedent → consequent` 的连边：

- 节点：商品编号（可回 `user_log` 表替换为 `itemname`）
- 边：关联规则
- 边宽或颜色：映射 `confidence` 或 `lift`，`lift > 1` 表示正相关

## 4. 部署运行

1. Eclipse 中新建 **Dynamic Web Project**，编译级别 1.8，Targeted Runtime 选 Tomcat 8.5
2. 把 `mysql-connector-java-5.1.40-bin.jar` 放入 `WebContent/WEB-INF/lib`
3. 确认 Tomcat 用 JDK8 启动（见 `01-环境部署.md` §8 的 `setenv.sh`）
4. 启动 Tomcat，浏览器访问：

```
http://localhost:8080/<工程名>/index.jsp
```

## 5. 可视化与分析的对应关系

```
Hive 统计（总量/大类/会员数）
        │  Sqoop
        ▼
MySQL supermarket.user_log ──┬──► 页面1 大类饼图
                             ├──► 页面2 饮品二级分类饼图
                             ├──► 页面3 各省会员气泡图
                             └──► 页面4 男女购买柱状图

PySpark FPGrowth
        │  JDBC
        ▼
MySQL supermarket.rules ────────► 页面5 商品关联关系图
```

## 6. 常见问题

| 现象 | 原因 | 处理 |
|---|---|---|
| 页面能打开但图表空白 | JSP 拿不到数据 | 先用 `System.out.println` 确认 SQL 有结果，再检查 ECharts 的 `xAxis`/`series` 字段名是否与 JSON 键一致 |
| 中文乱码 | 字符集未统一 | 确认 MySQL 库表 `utf8`、JDBC URL 带 `useUnicode=true&characterEncoding=utf8`、JSP `pageEncoding="UTF-8"` |
| `ClassNotFoundException: com.mysql.jdbc.Driver` | 驱动未进 classpath | jar 放入 `WEB-INF/lib` 并重新部署 |
| Eclipse 启动报 JDK 版本错 | 默认用了 JDK17 | 在 `eclipse.ini` 首部指定 `-vm` 为 jdk1.8.0_162 |
| 8080 端口被占 | Tomcat 已在运行 | `sudo lsof -i:8080` 查进程或改 `conf/server.xml` 端口 |
