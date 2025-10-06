# LIMIT句の件数に満たない件数を処理しようとするとエラーになる

## 事象

ローカル環境で[以下のような処理](処理ロジック)を実行すると、対象となるレコード数に関係なく必ず最後の処理にて以下のエラーが発生する

- `Error 1206: The total number of locks exceeds the lock table size`

### 環境

- `MySQL8.0 InnoDB`

### 処理ロジック

1. 対象となるレコードの件数を取得する
2. 5000件ずつ以下の処理を実行する
    1. トランザクションを開始する
    2. `exceeds_the_lock_table_size`テーブルからバックアップテーブル(`exceeds_the_lock_table_size_bk`)にINSERT...SELECTを5000件ずつ行う
    3. `exceeds_the_lock_table_size`テーブルから5000件ずつレコードを削除する
    4. コミットする
        1. 失敗した場合はロールバックする

- [参考ファイル](/doc/excceds_the_lock_table_size/execute.sh)

## 原因
> Error number: 1206; Symbol: ER_LOCK_TABLE_FULL; SQLSTATE: HY000
>
> Message: The total number of locks exceeds the lock table size
>
> InnoDB reports this error when the total number of locks exceeds the amount of memory devoted to managing locks. To avoid this error, increase the value of innodb_buffer_pool_size. Within an individual application, a workaround may be to break a large operation into smaller pieces. For example, if the error occurs for a large INSERT, perform several smaller INSERT operations.
>
> 引用: https://dev.mysql.com/doc/mysql-errors/8.0/en/server-error-reference.html

→ 要は、**ロック情報を管理するために割り当てられたメモリが不足した**際に発生するエラー

実際に`innodb_buffer_pool_size`を確認すると、デフォルトの**0.1GB**だった。

```sql
mysql> SELECT @@innodb_buffer_pool_size/1024/1024/1024;
+------------------------------------------+
| @@innodb_buffer_pool_size/1024/1024/1024 |
+------------------------------------------+
|                           0.125000000000 |
+------------------------------------------+
1 row in set (0.01 sec)

mysql>
```

## 対策

- `innodb_buffer_pool_size`の設定値をあげる

```sql
SET GLOBAL innodb_buffer_pool_size = 2150629376;
```

## 根本原因

そもそも5000件ごとに処理をしているのに、最後の処理(端数の処理※)にて発生するのがおかしい。5000の倍数の場合は発生しない。<br>
※対象件数が**10100件**ある場合、10000件は正常に処理されるが、最後の**100件**でエラーが発生していた

- 5000件はロックできるのに、100件がロックできない
- 対象レコードが10100件だろうと、20100件だろうと、最後の100件でエラーが発生する

調べると以下が複合的に影響していた

### LIMIT句で指定した値より、レコード数が少ない場合、全件走査をする

> LIMIT row_count を ORDER BY と組み合せると、MySQL はソート結果の最初の row_count 行を見つけた直後に、結果全体をソートするのではなくソートを停止します。
>
> 引用: https://dev.mysql.com/doc/refman/8.0/ja/limit-optimization.html

→裏を返すと、**見つからない場合は全件走査する**

### InnoDBでは、一意に特定できない条件の場合、スキャンしたインデックスをロックする(`REPEATABLE READ`)

> 一意の検索条件を使用した一意のインデックスの場合、InnoDB は見つかったインデックスレコードのみをロックし、その前にあるギャップはロックしません。
>
> その他の検索条件の場合、InnoDB は、ギャップロックまたはネクストキーロックを使用して、範囲に含まれるギャップへのほかのセッションによる挿入をブロックすることによって、スキャンされたインデックス範囲をロックします。 ギャップロックおよびネクストキーロックについては、セクション15.7.1「InnoDB ロック」 を参照してください。
>
> 引用: https://dev.mysql.com/doc/refman/8.0/ja/innodb-transaction-isolation-levels.html

### `FOR UPDATE`、`FOR SHARE`を指定しない`INSERT INTO ... SELECT`の場合、`REPEATABLE READ`が使用される

> 読取りのタイプは、FOR UPDATE または FOR SHARE を指定しない INSERT INTO ... SELECT、UPDATE ... (SELECT) および CREATE TABLE ... SELECT などの句での選択によって異なります:
>
>  ・デフォルトでは、InnoDB はこれらのステートメントに対してより強力なロックを使用し、SELECT 部分は READ COMMITTED のように動作します。この場合、各読取り一貫性は、同じトランザクション内であっても、独自の新しいスナップショットを設定および読み取ります。
>
>  ・このような場合に非ロック読取りを実行するには、トランザクションの分離レベルを READ UNCOMMITTED または READ COMMITTED に設定して、選択したテーブルから読み取られた行にロックを設定しないようにします。
>
> 引用: https://dev.mysql.com/doc/refman/8.0/ja/innodb-consistent-read.html

## 結論

1. 最後の端数を処理する際に、対象のレコードが見つからず(LIMIT row_countを満たせず)、全件走査している
2. `FOR UPDATE`等を指定しなかったため、`REPEATABLE READ`が使用された
    1. 一意に特定できないため、範囲ロックが行われた
3. `innodb_buffer_pool_size`が不足した


## 参考
- MySQL Documentation
   - [Chapter 2 Server Error Message Reference](https://dev.mysql.com/doc/mysql-errors/8.0/en/server-error-reference.html)
   - [8.2.1.19 LIMIT クエリーの最適化](https://dev.mysql.com/doc/refman/8.0/ja/limit-optimization.html)
   - [15.7.2.1 トランザクション分離レベル#REPEATABLE READ](https://dev.mysql.com/doc/refman/8.0/ja/innodb-transaction-isolation-levels.html)
      - [15.7.1 InnoDB ロック#ネクストキーロック](https://dev.mysql.com/doc/refman/8.0/ja/innodb-locking.html#innodb-next-key-locks)
   - [15.7.2.3 一貫性非ロック読み取り](https://dev.mysql.com/doc/refman/8.0/ja/innodb-consistent-read.html)
