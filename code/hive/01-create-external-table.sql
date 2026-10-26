-- =============================================================
-- 01 - 创建数据库与 Hive 外部表
-- 依据：第3章-3.4项目实践.pptx §3.4.1「在数据仓库Hive上创建数据库」
--
-- 用法：
--   hive -f code/hive/01-create-external-table.sql
--
-- 前置：
--   CSV 已转 UTF-8、删除表头，并上传到 HDFS
--   /supermarket/dataset/user_log/
-- =============================================================

create database if not exists supermarket;
use supermarket;

-- 外部表：数据文件由 HDFS 管理，删表不删数据
create external table if not exists supermarket.user_log (
    id            STRING,   -- 数据ID
    itemcode      STRING,   -- 商品编号
    itemname      STRING,   -- 商品名称
    ficheno       STRING,   -- 会员卡号
    merchant_date STRING,   -- 日期
    amount        DOUBLE,   -- 数量
    price         DOUBLE,   -- 单价
    linenettotal  DOUBLE,   -- 总价
    linenet       DOUBLE,   -- 优惠价格
    branchnr      STRING,   -- 分店编号
    branch        STRING,   -- 分店
    salesman      STRING,   -- 售货员
    city          STRING,   -- 分店所在城市
    region        STRING,   -- 所属八大区域
    latitude      DOUBLE,   -- 纬度
    longitude     DOUBLE,   -- 经度
    clientcode    STRING,   -- 收银台编号
    clientname    STRING,   -- 顾客名称
    brandcode     STRING,   -- 品牌编号
    brand         STRING,   -- 品牌
    category_I    STRING,   -- 商品一级分类
    category_II   STRING,   -- 商品二级分类
    category_III  STRING,   -- 商品三级分类
    startdate     STRING,   -- 收银开始时间
    enddate       STRING,   -- 收银结束时间
    sex           STRING    -- 会员性别
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/supermarket/dataset/user_log';

-- 校验：应命中 61 万条左右
select count(*) as total_rows from user_log;
