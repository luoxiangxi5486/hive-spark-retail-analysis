#!/usr/bin/env bash
#
# Sqoop 把 Hive 内部表数据导出到 MySQL
# 依据：第3章-3.4项目实践.pptx §3.4.1 第17页（含课件原始参数）
#
# 用法：
#   bash code/sqoop/export-hive-to-mysql.sh
#
# 前置：
#   1. Hive 中已建好 supermarket.inner_user_log 并已 INSERT OVERWRITE
#      （执行 code/hive/03-inner-table.sql）
#   2. MySQL 中已建好 supermarket.user_log（执行 code/mysql/01-create-tables.sql）
#   3. MySQL 服务运行中
#
set -euo pipefail

# ---------------- 可按环境调整的参数 ----------------
SQOOP_HOME="${SQOOP_HOME:-/usr/local/sqoop}"

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-3306}"
DB_NAME="${DB_NAME:-supermarket}"
DB_USER="${DB_USER:-root}"
DB_PASS="${DB_PASS:-123456}"

TARGET_TABLE="${TARGET_TABLE:-user_log}"
HIVE_EXPORT_DIR="${HIVE_EXPORT_DIR:-/user/hive/warehouse/supermarket.db/inner_user_log}"
FIELD_SEP="${FIELD_SEP:-,}"
# ---------------------------------------------------

echo "== 检查前置条件 =="
command -v hadoop >/dev/null 2>&1 || echo "  [警告] 未在 PATH 中找到 hadoop"

if ! (echo > /dev/tcp/"${DB_HOST}"/"${DB_PORT}") >/dev/null 2>&1; then
    echo "  [错误] 无法连接 MySQL ${DB_HOST}:${DB_PORT}" >&2
    exit 1
fi
echo "  MySQL ${DB_HOST}:${DB_PORT} 可达"

echo
echo "== 开始导出 =="
echo "  源目录: ${HIVE_EXPORT_DIR}"
echo "  目标表: ${DB_NAME}.${TARGET_TABLE}"

cd "${SQOOP_HOME}"

bin/sqoop export \
    --connect "jdbc:mysql://${DB_HOST}:${DB_PORT}/${DB_NAME}?useUnicode=true&characterEncoding=utf8" \
    --username "${DB_USER}" \
    --password "${DB_PASS}" \
    --table "${TARGET_TABLE}" \
    --export-dir "${HIVE_EXPORT_DIR}" \
    --fields-terminated-by "${FIELD_SEP}" \
    --input-null-string '\\N' \
    --input-null-non-string '\\N'

echo
echo "== 导出完成，校验行数 =="
mysql -h "${DB_HOST}" -P "${DB_PORT}" -u "${DB_USER}" -p"${DB_PASS}" \
      -e "select count(*) as exported_rows from ${DB_NAME}.${TARGET_TABLE};"

# 备注：
#   - 若导出后各列整体错位一位，通常是 MySQL 表列顺序与 Hive 内部表不一致，
#     请对照 code/mysql/01-create-tables.sql 与 code/hive/03-inner-table.sql 的列序。
#   - --input-null-string '\\N' 用于把 Hive 的 NULL 标记正确映射为 MySQL NULL，
#     避免字符串 "\N" 被当成真实内容写入。
