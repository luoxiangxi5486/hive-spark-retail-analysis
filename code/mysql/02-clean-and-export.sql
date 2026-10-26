-- =============================================================
-- 02 - MySQL 数据清洗与结果导出
-- 依据：第3章-3.4项目实践.pptx §3.4.1 第18~23页
--
-- 用法：
--   mysql -u root -p123456 < code/mysql/02-clean-and-export.sql
--
-- 说明：后续分析只用 sex、category_I、category_II、city 四列，
--       因此只清理这四列的空值行。
-- =============================================================

use supermarket;

-- ------------------------------------------------------------
-- 1. 先统计各列空值行数量（记录清洗前基线）
-- ------------------------------------------------------------
select 'city'        as col, count(*) as empty_cnt from user_log where city        = ''
union all
select 'category_I'  as col, count(*) as empty_cnt from user_log where category_I  = ''
union all
select 'category_II' as col, count(*) as empty_cnt from user_log where category_II = ''
union all
select 'sex'         as col, count(*) as empty_cnt from user_log where sex         = '';

-- 清洗前总行数
select count(*) as before_clean from user_log;

-- ------------------------------------------------------------
-- 2. 删除空值行
-- ------------------------------------------------------------
delete from user_log where city        = '';
delete from user_log where category_I  = '';
delete from user_log where category_II = '';
delete from user_log where sex         = '';

-- 清洗后总行数
select count(*) as after_clean from user_log;

-- ------------------------------------------------------------
-- 3. 导出为 CSV（不含表头）
--    路径须落在 secure_file_priv 允许的目录内，先确认：
--    show variables like "secure_file_priv";
-- ------------------------------------------------------------
select * from user_log
into outfile '/var/lib/mysql-files/MarketSales_341results.csv'
fields terminated by ',' lines terminated by '\n';

-- ------------------------------------------------------------
-- 4. 导出为 CSV（含表头，用 union all 拼一行列名）
-- ------------------------------------------------------------
select * from (
    select 'id','itemcode','itemname','ficheno','merchant_date','amount','price',
           'linenettotal','linenet','branchnr','branch','salesman','city','region',
           'latitude','longitude','clientcode','clientname','brandcode','brand',
           'category_I','category_II','category_III','startdate','enddate','sex'
    union all
    select id, itemcode, itemname, ficheno, merchant_date, amount, price,
           linenettotal, linenet, branchnr, branch, salesman, city, region,
           latitude, longitude, clientcode, clientname, brandcode, brand,
           category_I, category_II, category_III, startdate, enddate, sex
    from user_log
) b
into outfile '/var/lib/mysql-files/MarketSales_341results.csv'
fields terminated by ',' lines terminated by '\n';

-- 导出后拷回数据目录并开放读权限：
--   sudo cp /var/lib/mysql-files/MarketSales_341results.csv /home/hadoop/data/
--   sudo chmod 777 /home/hadoop/data/MarketSales_341results.csv
