---
title: "スカッシュマージをマージコミットに置き換える"
emoji: "🎈"
type: "tech"
topics: [git, github]
published: true
publication_name: socialdog
---

SocialDog は 3 年半ほど前、プルリクエストをマージするときの運用を「スカッシュマージする」運用から「マージコミットを作る」運用へと移行し、その経緯を以下ブログ記事で紹介しました。

https://www.wantedly.com/companies/socialdog/post_articles/461640

この記事でおまけとして紹介した **「スカッシュマージの履歴をマージコミットと同様に見る方法」** を最近社内 LT 会の折に整理し、リポジトリとして公開したので紹介します。

前置き不要で使い方を知りたい方は [こちらから](#git-inflate-の紹介) どうぞ。

## スカッシュマージとマージコミットの違い

まず前提として、プルリクエストをマージする 2 つの方法について簡単に説明します。[^merge-kind] [^github-merge]

[^merge-kind]: 「rebase してマージ」もありますが割愛します
[^github-merge]: [プルリクエストのマージについて - GitHubドキュメント](https://docs.github.com/ja/pull-requests/collaborating-with-pull-requests/incorporating-changes-from-a-pull-request/about-pull-request-merges)

### マージコミット

恐らくスタンダードといってよいマージ方法は、ブランチで積み上げたコミットをそのまま残す、**マージコミットを作成する** 方法です。

ここでいうマージコミットとは、**2つの親コミット** を持つコミットのことです。[^merge-parent] メインブランチの HEAD と開発ブランチの HEAD の 2 つを親として持ち、2つの履歴を繋ぎ合わせます。

![マージコミット方式の git グラフ。main ブランチ上のコミット A→B→G→M→H と、B から分岐した feature ブランチの C→D→E→F が、マージコミット M で合流する様子を表す](/images/inflate-squashed-commit-1.png)

上の図では、マージコミット `M` は、`G` と `F` の2つを親に持ちます。つまり、feature ブランチで積んだ `C` `D` `E` `F` のコミットは main ブランチ中の `M` から辿ることができます。

[^merge-parent]: 厳密には「3つ以上の親」も持つことができますが、本記事公開時点では GitHub 上でそのようなコミットを直接作成することはできません

### スカッシュマージ

スカッシュマージでは、ブランチ上の複数コミットの変更内容を **1つのコミットにまとめて** マージします。作成されるのは通常のコミットと同じ、親が1つだけのコミットです。

![スカッシュマージの git グラフ。main ブランチ上の A→B→G→S→H が一直線に並び、スカッシュマージで生じた S が黄色く強調されている](/images/inflate-squashed-commit-2.png)

上の図では feature ブランチ上で積まれた `C` `D` `E` `F` を main ブランチにマージするときに 1 つのコミット `S` にまとめている様子を示しています。

### git log での見え方

この構造の違いは `git log --graph --oneline` の出力でわかりやすく見ることができます。

マージコミットを作成する運用の出力例を次に示します。ブランチ上で積まれたコミットがプルリクエストでマージされ、ベースブランチに合流する様子がわかります。

```
* 9f2e1d0 (HEAD -> main) Update README
*   7a3b4c5 Merge pull request #2 from user/fix-typo
|\  
| * c6d7e8f Fix typo in header
| * b5a4f3e Update wording
|/  
*   3e1f2a4 Merge pull request #1 from user/add-feature
|\  
| * f8e7d6c Add integration tests
| * a1b2c3d Implement new feature
| * 9d8c7b6 Add feature flag
|/  
* 2b3c4d5 Initial commit
```

もし上記がスカッシュマージでマージされていたら、次のような出力になります。

```
* 8e1d0c9 (HEAD -> main) Update README
* 4f5a6b7 Fix typo in header (#2)
* d8e9f0a Add new feature (#1)
* 2b3c4d5 Initial commit
```

スカッシュマージでは「通常のコミット」と「スカッシュマージのコミット」とは区別されず、直線的なコミットグラフになることがわかります。

## スカッシュマージで失われるもの

先ほどのコミットグラフを見ると一見スカッシュマージはすっきりして見えます。^[マージコミットでも `git log --first-parent` を使えば第1の親だけをたどり、事実上スカッシュマージ相当のログを確認できます]
ただ、次のような情報が失われています[^trunk]：

- 変更単位の粒度
  プルリクエストの差分すべてが 1 つのコミットになるため、運用面で工夫しない限り、複数の変更単位が 1 つのコミットに含まれやすくなります。
  これにより、変更の経緯をログ上で確認しづらくなったり、一部の差分だけ revert や cherry-pick したいケースに対応できないといった制約に繋がります。
- 実際の履歴
  スカッシュマージでは、メインブランチの履歴に開発ブランチのコミットハッシュがそのまま残りません。
  例えば「修正コミット `123abc` が含まれるブランチを一覧したい」場合、 マージコミットを作る運用であれば、`git branch --all --contains 123abc` といったコマンドでブランチを一覧できますが、スカッシュマージの運用ではこれができません。

スカッシュマージの制約については[冒頭に紹介した記事](https://www.wantedly.com/companies/socialdog/post_articles/461640)で詳しく説明しているため、興味があればこちらもご参考ください。

[^trunk]: トランクベースのワークフロー（常にメインブランチから短命なブランチを切り、すぐにマージする）を厳密に運用している場合は、この問題は顕在化しづらいと思われます]

## スカッシュコミットに第2の親を与える

スカッシュマージで失われた情報を、どうしても使いたいときはどうすればよいでしょうか？

ここで視点を変えてみます。


![スカッシュマージ後の現状。`main` ブランチ上に `S`（スカッシュコミット）があり、`B` から分岐した `feature` ブランチの `C`→`D`→`E`→`F` は残っているものの、`F` から `S` への合流の矢印がない](/images/inflate-squashed-commit-3.png)

この図ではスカッシュコミット `S` は `G` だけを親に持っています。ここに **`F` を第2の親として追加** できれば、構造上マージコミットと同等になるはずです。
<!-- `S` は `G` のみを親に持ち、feature ブランチとの繋がりがありません。 -->

![`S'` が `G` と `F` の 2 つを親に持てれば、`S` と同等になる](/images/inflate-squashed-commit-4.png)

<!-- `S'` が `G` と `F` の2つを親に持てば、`git log --graph` でブランチの分岐・合流が見えるようになり、マージコミットと同じ構造になります。`S'` は `S` と同じ変更内容を持ちつつ、親が異なる別のコミットです。-->

## git-replace でコミットを置き換える

Git の機能 [git-replace](https://git-scm.com/docs/git-replace) を使うと、ローカル環境限定ですが上記のアイデアを実現することができます。

git-replace は、ある [Git オブジェクト](https://git-scm.com/book/ja/v2/Git%E3%81%AE%E5%86%85%E5%81%B4-Git%E3%82%AA%E3%83%96%E3%82%B8%E3%82%A7%E3%82%AF%E3%83%88)を **別のオブジェクトで透過的に置き換える** コマンドです。[^git-replace-usecase]

次のような特徴があります：

- `refs/replace/` 配下に「どのオブジェクトをどのオブジェクトで読み換えるか」を管理する ref を作成する^[commit オブジェクトであれば commit オブジェクトで置き換えるなど、同じ種類のオブジェクトで置き換える必要があります]
- この読み換えは `git log` や `git show` コマンドなど、ほとんどの git コマンドで自動適用される
- 置換元のオリジナルオブジェクトは変更されない^[そもそもオブジェクトの内容によってSHAハッシュが決まるため、同一のハッシュをもつオブジェクトで置換することは事実上不可能です]

[^git-replace-usecase]:「fork 時に履歴を作り直したリポジトリ間の履歴を繋げる」のがよく見る使い方です

### `--graft` オプション

git-replace には `--graft` という便利なオプションがあるので合わせて紹介します。

このオプションをつけると、コミットの内容はそのままに、**親だけを差し替えて** 新しいコミットオブジェクトを自動生成します。

```bash
git replace --graft <置き換え対象のコミットハッシュ> [<親コミットのハッシュ>...]
```

`--graft` を使わない場合、自分でコミットオブジェクトを手作りする低レベルな操作^[`git commit-tree` コマンドを使って自身でコミットオブジェクトを作成するなど]が必要になりますが、このオプションのおかげでその手間が省けます。

## GitHub 上の開発ブランチ HEAD を見つける

プルリクエストがマージされたあと、マージしたブランチがマージ時点のまま残っているとは限りません。

ただ GitHub は各プルリクエストのブランチ先頭を `refs/pull/<番号>/head` として保持しています。

```bash
$ git ls-remote origin 'refs/pull/*/head'
a1b2c3d  refs/pull/1/head
d4e5f6a  refs/pull/2/head
b7c8d9e  refs/pull/3/head
...
```

プルリクエストがマージされたあと、これらの refs は更新されません。
そして次のように fetch コマンドを使うことで、ローカルに取得し、利用することができます。

```bash
git fetch origin 'refs/pull/*/head:refs/pull/*/head'
```

## git-inflate の紹介

https://github.com/na0x2c6/git-inflate

git-inflate は、ここまでの要素を組み合わせ、**スカッシュコミットからマージコミットへの置き換えを自動化する** スクリプトです。


### インストール・基本的な使い方

`git-inflate` スクリプトを PATH の通った場所に配置すれば、そのまま

```bash
git inflate
```

と実行すれば利用できます。

フラグなしのデフォルト実行で、GitHub 管理のリポジトリを前提とした fetch・replace を自動実行します。

細かな使い方は README を参考ください。

## 制約と注意点

### cherry-pick との区別

git-inflate は、以下 2 つが満たされるコミットを「スカッシュマージによるコミット」とみなします。

1. コミットメッセージに `(#プルリクエスト番号)` という文字列が含まれている^[マッチに使う正規表現はフラグで変更可能です]
2. 親コミットと 1 でマッチしたプルリクエストの HEAD をマージすると、同一のツリーハッシュ ^[tree オブジェクトのハッシュ。一致すればコミットされたワークツリーが完全にマッチするといえる] を得られる

もしスカッシュマージしたコミットを何らかの理由で `git cherry-pick` して別のコミットを作っていた場合、スカッシュコミットと同じコミットメッセージでコミットされているかもしれません。（1 に該当する）

そしてチェリーピック後のファイルツリーがスカッシュマージのファイルツリーと完全に一致するならば（2 に該当する） ^[環境別にブランチが用意され、cherry-pick で機能を展開するようなケースなど]、「スカッシュマージによるコミット」と「チェリーピックによるコミット」を完全に区別することができず、後者も置き換え対象となります。

この点を踏まえても、完全に正確な動作を保証するものではありません。

### GitHub API を使わない理由

厳密なプルリクエストの特定には GitHub API を使う方法もありますが、以下の理由からあえて採用していません。

- デバッグの難しさ
    
    本スクリプトは大量のコミットをもつリポジトリに対しても実行され得ます。GitHub API を実際に叩きながら動作を確認するような設計方針は採用しづらいと考えています。
    
- 汎用性
    
    GitHub 以外でも使えるようにしたかったためです。API の取り扱いを差し替え可能にするのはやや面倒だと思いました。
    

と、もっともらしいことを書いてみましたが、実際のところ「自分のユースケースで満足できればよい」くらいで設計しています。

### replace オブジェクトを無視する方法

git-replace で置き換えたコミットを一時的に無効化し、元のオブジェクトを確認したい場合は `--no-replace-objects` フラグが使えます。

```bash
git --no-replace-objects log # 元の履歴を見る
```

### git-replace の既知のバグ

git のバージョン `2.44.0` 時点で、git-replace の[公式ドキュメント](https://git-scm.com/docs/git-replace/2.44.0#_bugs)には BUGS セクションが存在します。

> Comparing blobs or trees that have been replaced with those that replace them will not work properly. And using `git reset --hard` to go back to a replaced commit will move the branch to the replacement commit instead of the replaced commit.

replace オブジェクトを使う場合、少なくともこの制約に注意が必要です。

---

Git の低レベルな概念を理解すると柔軟なユースケースに対応できますね。ただ `git-inflate` はあくまでワークアラウンド的な用途を想定しているため、ご利用の際はご注意ください。
