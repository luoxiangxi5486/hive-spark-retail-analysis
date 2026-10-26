-- =============================================================
-- 03 - 创建内部表，为 Sqoop 导出做准备
-- 依据：第3章-3.4项目实践.pptx §3.4.1「创建临时表」「INSERT OVERWRITE」
--
-- 原因：Sqoop 导出读取的是 Hive 内部表在
--       /user/hive/warehouse/<db>.db/<table> 下的数据文件。
--       外部表的 LOCATION 指向自定义 HDFS 路径，Sqoop 直接导会取不到。
--
-- 用法：
--   hive -f code/hive/03-inner-table.sql
-- =============================================================

use supermarket;

create table if not exists supermarket.inner_user_log (
    id            STRING,
    itemcode      STRING,
    itemname      STRING,
    ficheno       STRING,
    merchant_date STRING,
    amount        DOUBLE,
    price         DOUBLE,
    linenettotal  DOUBLE,
    linenet       DOUBLE,
    branchnr      STRING,
    branch        STRING,
    salesman      STRING,
    city          STRING,
    region        STRING,
    latitude      DOUBLE,
    longitude     DOUBLE,
    clientcode    STRING,
    clientname    STRING,
    brandcode     STRING,
    brand         STRING,
    category_I    STRING,
    category_II   STRING,
    category_III  STRING,
    startdate     STRING,
    enddate       STRING,
    sex           STRING
)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

-- 外部表数据写入内部表
insert overwrite table supermarket.inner_user_log
select * from supermarket.user_log;

-- 校验：两者行数应一致
select 'external' as src, count(*) as cnt from supermarket.user_log
union all
select 'inner'    as src, count(*) as cnt from supermarket.inner_user_log;

-- 内部表数据物理位置（Sqoop 的 --export-dir 就填这个路径）
-- /user/hive/warehouse/supermarket.db/inner_user_log
