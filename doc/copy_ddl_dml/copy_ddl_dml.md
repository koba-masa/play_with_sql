---
title: データベースのDDL・DMLをコピーする際の注意点
slide: true
marp: true
---

# データベースのDDL・DMLをコピーする際の注意点

---

# 前置き

私が運用・保守の案件で仕事をしていた時にDBAチームに配属されました。
その時に学んだノウハウです。
2015〜6年くらいかな(社会人4年目くらい)

---

# 案件概要

- 保険のシステム開発

# 業務内容

- ソースコードのビルド
- テスト環境の構築及びテスト環境へのデプロイ
- 本番環境へのデプロイ手順の構築・検証・リリース作業

---

# 背景

- プロジェクトチームが多岐に渡り、チーム間のコンフリクトの確認をする必要があった
- プロジェクトごとにテスト環境を構築する必要があり、どのチームがどういう状態で使うのかを管理する必要があった
  - 7環境くらいあった気がする

---

# 作業内容

今回説明するノウハウを使っていた業務内容

- 本番環境のデータベースの状態をテスト環境Aに反映する
- 特定の日付時点のテスト環境Aのデータベースをテスト環境Bに反映する
- 特定の日付時点のテスト環境Aのデータベース(DDLのみ)をテスト環境Cに反映する
- 特定の日付時点のテスト環境Aのデータベース(DMLのみ)をテスト環境Dに反映する

要はDBのダンプを取得して、別のDBにインポートするということをしていました。

---

# ダンプ対象

- DDL
  - Trigger
  - Materialized View
  - Function
  - Stored Procedure
  - Table
  - Index
  - View
  - Sequence
- DML

---

オブジェクトごとにエクスポートしています。

```
exports/
  └ dml.sql
  └ function.sql
  └ index.sql
  └ materialized_view.sql
  └ sequence.sql
  └ stored_procedure.sql
  └ table.sql
  └ trigger.sql
  └ view.sql
```

---

# さて、インポートする順番があります。どういう順でしょうか？

zoomのコメント欄に投稿してみてください。

---

# 正解

状況に応じて変わりはするものの、当時こうやって作業していたので、一旦以下を正解します

1. Table
2. Function
3. View
4. Materialized View
5. DML
6. Index
7. Stored Procedure
8. Sequence
9. Trigger

---

# 解説

---

## Table

テーブルがないと何も始まらない

---

## Sequence

Triggerから呼び出されることがあるため、Triggerよりも先に作成する
DML

---

## Function

FunctionはViewから参照されることもあるので、Viewより先に作成する

---

## View

ViewはTableないし、Viewを参照するので、必ずTableのインポート後にインポートする必要がある

※ViewがViewを参照することもあるので、作成されていないオブジェクトを参照した場合にエラーが発生するので、再度実行する

---

## Materialize View

MViewもViewと同様にTableとViewを参照するため、Table→View→MViewという順になる
※DMLの投入前後のどちらでも良いが、投入前に作成した場合はリフレッシュする必要がある

---

## DML

以下を参照
- Index
- Trigger

---

## Index

DMLが大量にデータがある場合、先にIndexを貼ってしまうとインポートに時間がかかってしまうので、データ投入した後にIndexを貼る

---

## Stored Procedure

Triggerから呼び出されることがあるため、Triggerよりも先に作成する

---

## Trigger

移行元のDBからトリガーが発火した後の状態のものをダンプしています。
他のオブジェクトよりも先に作成してしまうと、例えばDMLの投入してTriggerが発火し、移行元のDBとは状態が変わってしまうため、一番最後にインポートする

---

以上
