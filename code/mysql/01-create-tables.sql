-- =============================================================
-- 01 - MySQL 侧建库建表（承接 Sqoop 导出）
-- 依据：第3章-3.4项目实践.pptx §3.4.1「创建数据库/创建表」
--
-- 用法：
--   mysql -u root -p123456 < code/mysql/01-create-tables.sql
--
-- 注意：列顺序必须与 Hive 内部表 inner_user_log 完全一致，
--       Sqoop 按位置映射字段，顺序错位会导致数据串列。
-- =============================================================

create database if not exists supermarket
    default charset utf8 collate utf8_general_ci;

use supermarket;

drop table if exists user_log;

create table `supermarket`.`user_log` (
    `id`            varchar(100),
    `itemcode`      varchar(100),
    `itemname`      varchar(100),
    `ficheno`       varchar(100),
    `merchant_date` varchar(100),
    `amount`        varchar(20),
    `price`         varchar(20),
    `linenettotal`  varchar(20),
    `linenet`       varchar(20),
    `branchnr`      varchar(20),
    `branch`        varchar(100),
    `salesman`      varchar(100),
    `city`          varchar(100),
    `region`        varchar(100),
    `latitude`      varchar(20),
    `longitude`     varchar(20),
    `clientcode`    varchar(20),
    `clientname`    varchar(100),
    `brandcode`     varchar(20),
    `brand`         varchar(100),
    `category_I`    varchar(100),
    `category_II`   varchar(100),
    `category_III`  varchar(100),
    `startdate`     varchar(100),
    `enddate`       varchar(100),
    `sex`           varchar(20)
) engine = InnoDB default charset = utf8;

-- 导出完成后校验行数（应在 61 万左右）
-- select count(*) from user_log;
