-- =============================================================
-- 02 - Hive 统计查询分析
-- 依据：第3章-3.4项目实践.pptx §3.4.1「使用Hive查询分析」
--
-- 用法：
--   hive -f code/hive/02-analysis-queries.sql
-- =============================================================

use supermarket;

-- ------------------------------------------------------------
-- 1. 总数据量
-- ------------------------------------------------------------
select count(*) as total_rows from user_log;

-- ------------------------------------------------------------
-- 2. 商品一级分类（超市大类）
-- ------------------------------------------------------------
select distinct category_I from user_log order by category_I;

-- ------------------------------------------------------------
-- 3. 会员数量（按会员卡号去重）
-- ------------------------------------------------------------
select count(distinct ficheno) as member_cnt from user_log;

-- ------------------------------------------------------------
-- 4. 带条件的二级分类查询
-- ------------------------------------------------------------
select distinct category_II from user_log where category_I = 'FOOD'  order by category_II;
select distinct category_II from user_log where category_I = 'DRINK' order by category_II;

-- ------------------------------------------------------------
-- 5. 以下为可视化页面所需的扩展统计
--    （课件未逐条列出，按页面需求补充，可直接对应 MySQL 侧查询）
-- ------------------------------------------------------------

-- 页面1：各大类成交量
select category_I, count(*) as num
from user_log
group by category_I
order by num desc;

-- 页面2：饮品 DRINK 下各二级分类成交量
select category_II, count(*) as num
from user_log
where category_I = 'DRINK'
group by category_II
order by num desc;

-- 页面3：各省会员人数
select city, count(distinct ficheno) as num
from user_log
group by city
order by num desc;

-- 页面4：男女会员各品类购买量
select sex, category_I, count(*) as num
from user_log
group by sex, category_I
order by sex, num desc;
