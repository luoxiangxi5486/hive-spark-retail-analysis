-- =============================================================
-- 03 - 关联规则结果表（PySpark 通过 JDBC 写入）
-- 依据：第3章-3.4项目实践.pptx §3.4.2 第48~50页
--
-- 用法：
--   mysql -u root -p123456 < code/mysql/03-create-rules-table.sql
--
-- 注意：Spark 以 append 模式写入，因此表不存在时会报错，
--       必须先执行本脚本建表。
-- =============================================================

use supermarket;

drop table if exists rules;

create table `rules` (
    `antecedent` varchar(100),   -- 前项：顾客已购买的商品编号
    `consequent` varchar(100),   -- 后项：被连带购买的商品编号
    `confidence` double,         -- 置信度
    `lift`       double          -- 提升度，>1 表示正相关
) engine = InnoDB default charset = utf8;

-- 校验写入结果
-- select count(*) from rules;
-- select * from rules order by lift desc limit 20;

-- ------------------------------------------------------------
-- 导出关联规则 CSV（含表头），供可视化页面5使用
-- ------------------------------------------------------------
-- select * from (
--     select 'antecedent','consequent','confidence','lift'
--     union all
--     select antecedent, consequent, confidence, lift from rules
-- ) b
-- into outfile '/var/lib/mysql-files/rules.csv'
-- fields terminated by ',' lines terminated by '\n';
--
-- 导出后：
--   sudo cp /var/lib/mysql-files/rules.csv /home/hadoop/data/
--   sudo chmod 777 /home/hadoop/data/rules.csv
