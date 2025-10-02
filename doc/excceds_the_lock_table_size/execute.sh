#!bin/sh

DB_HOST="127.0.0.1"
DB_NAME="play_with_sql"

LIMIT=1000

SQL_SELECT_COUNT="""
  SELECT COUNT(*) FROM exceeds_the_lock_table_size WHERE is_active = FALSE;
"""

SQL_INSERT_SELECT="""
  INSERT INTO exceeds_the_lock_table_size_bk (id, name, email, created_at)
      SELECT id, name, email, created_at FROM exceeds_the_lock_table_size
          WHERE is_active = FALSE ORDER BY id LIMIT ${LIMIT}
  ;
"""

SQL_DELETE="""
  DELETE FROM exceeds_the_lock_table_size WHERE is_active = FALSE ORDER BY id LIMIT ${LIMIT};
"""

COUNT=$(mysql -h ${DB_HOST} ${DB_NAME} -N -e "${SQL_SELECT_COUNT}")

i=0

while [ ${i} -lt ${COUNT} ]; do
   # BEGIN;

    mysql -h ${DB_HOST} ${DB_NAME} -N -e "${SQL_INSERT_SELECT}"

    mysql -h ${DB_HOST} ${DB_NAME} -N -e "${SQL_DELETE}"

    # COMMIT or ROLLBACK;

    i=$((i + $LIMIT))
done
