---
title: "複数の Docker Compose 環境を同時に立ち上げる"
emoji: "🐳"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: ["zennfes2025free", "dockercompose", "docker", "claudecode", "git"]
published: true
publication_name: socialdog
---

## はじめに

[Docker Compose](https://docs.docker.com/compose/) を利用して開発環境を構築するプロジェクトは多いと思います。

[Claude Code](https://docs.claude.com/ja/docs/claude-code/overview) をはじめとするコーディングエージェントの普及により、[git-worktree を使って複数の作業ブランチを並行して開発することが増えてきました](https://zenn.dev/search?q=git%2520worktree&order=latest)。Docker Compose で構築する開発環境は、ワークツリーが違えどほとんどの場合同じような構成になるため、**ワークツリーごとに環境を立ち上げようとすると、コンテナ名やポートの衝突といった問題が発生します。**

SocialDog では、[git-worktree](https://git-scm.com/docs/git-worktree) を使った開発においても、これらの問題が生じないよう手順をドキュメント化しています。

![](https://storage.googleapis.com/zenn-user-upload/1dd66bfafb53-20251019.png)
*5環境並列で動かしています*

本記事では、私たちが開発で利用している **Docker Compose を複数立ち上げても環境を衝突させない構成例** を紹介します。

## この記事で書くこと

- 複数の Docker Compose 環境を扱う上での構成例
  - 環境間でコンテナやネットワークの衝突を防ぐ方法
  - ポートバインディングの衝突を防ぐ方法
  - ポートバインディング自体を回避する方法
- Claude Code で複数の環境を使いわける例

## この記事で書かないこと

- Docker Compose の基本的な操作方法
- git-worktree の詳しい使い方
- Claude Code の使い方

## 複数の Docker Compose 環境の問題

git-worktree は、リポジトリを複数のワークツリー（ディレクトリ）にチェックアウトできる [git](https://git-scm.com/) の機能です。

「ローカル環境に複数のブランチを別ディレクトリで同時にチェックアウトできる」^[ブランチに限りません]ということですが、それぞれのワークツリー^[ここでは `git worktree add` で作成したディレクトリおよび作業領域のこと]で Docker Compose によるコンテナを起動すると、次のような問題に直面します。

### コンテナ環境の衝突

例えば git リポジトリのプロジェクトルート `work-A` 内で `git worktree add ../work-B` を実行し、次のように [Compose ファイル](https://docs.docker.com/compose/intro/compose-application-model/#the-compose-file)（ここでは `compose.yaml`） が存在する例を考えます。

- `work-A/services/compose.yaml`
- `work-B/services/compose.yaml`

ここで、以下操作を順番に実施することを考えます。

1. `work-A/services/` 直下で `docker compose up` する
2. `work-B/services/` 直下で `docker compose down` する

すると、1. の `work-A/services/` で起動したコンテナやネットワークは、 **2. の操作時に削除されてしまいます。**^[各ワークツリーの `compose.yaml` ファイルに差異がある場合などはこの限りではありません]

これは、それぞれの `compose.yaml` ファイルが **同じディレクトリ名 `services` の配下に存在する** ことによって起きる問題です。

Docker Compose はデフォルトで、「Compose ファイルが配置されたディレクトリ名」を**プロジェクト名**として扱います。

https://docs.docker.com/compose/how-tos/project-name/

今回のケースでは、ワークツリーが別であっても **Compose ファイルが存在するディレクトリ名は変わらない**ため、ワークツリー間で同じプロジェクト名（`services`）が使われます。

このプロジェクト名は[名前空間](https://en.wikipedia.org/wiki/Namespace)の役割を果たすので、別のワークツリーで作成したコンテナやネットワークであっても、**同じプロジェクト名で管理されていれば削除してしまう**のです。

#### プロジェクト名でコンテナ環境を分離する

つまりコンテナ環境の衝突をさけるシンプルな解決方法は、**プロジェクト名を環境ごとに設定する**ことです。

ドキュメントでは、[次の優先度でプロジェクト名が決定されるとあります。](https://docs.docker.com/compose/how-tos/project-name/#set-a-project-name)

1. `docker compose` コマンドの `-p` フラグ
2.  `COMPOSE_PROJECT_NAME` 環境変数
3. Compose ファイル内のトップ属性 `name`^[`-f` フラグで複数指定されたときは最初に指定されたファイル]
4. Compose ファイルが存在するディレクトリ名^[`-f` フラグで複数指定されたときは最初に指定されたファイルが存在するディレクトリ名]
5. カレントディレクトリ名（Compose ファイルが指定されない場合）^[特に `-f -` を指定し標準入力から Compose 定義を与えた場合が該当すると思われます]

筆者のオススメは、`COMPOSE_PROJECT_NAME` 環境変数の設定です。ただし、シェルの環境変数として設定するのではなく、 **[`.env` ファイル](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/)** で定義します。 `.env` は Compose ファイルと同じディレクトリに作成します。

```text:.env
COMPOSE_PROJECT_NAME=some-project
```

`.env` ファイルは後述する「Interporation で変数の値を設定するためのファイル」ですが、`COMPOSE_PROJECT_NAME` などの **[事前定義された環境変数（pre-defined environment variables）](https://docs.docker.com/compose/how-tos/environment-variables/envvars/)** の値を直接設定するのにも[利用できます](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/#local-env-file-versus-ltproject-directorygt-env-file)。

### バインドポートの衝突

コンテナ環境の衝突はプロジェクト名を区別することで回避できますが、
より直接的に問題が起きるのは、ホストへのバインドポートが衝突することです。

開発環境では、データベースや Web サーバーなどのアプリケーションポートをホストにバインドすることが一般的です。しかし「ホストの同じポート番号に対し、複数のコンテナがポートバインドを試行する」とエラーになってしまいます。

例えば次のような Compose ファイルでコンテナを起動（`docker compose up`）すると、コンテナのポート 80 番をホストのポート 8000 番へバインド（割り当て）します。

```yaml:compose.yaml
services:
  web:
    image: docker.io/nginx:stable
    ports:
      - "8000:80"
```

このコンテナを起動したまま、同じ内容の Compose ファイルで別のコンテナを起動すると、先程起動済のコンテナがすでにポート 8000 番へバインド済のため、エラーになります。


#### 方法 1：Interporation を使ったバインドポートの変更

まずホストへのバインドポートを**動的に変更し衝突を回避する**例を紹介します。

先ほど示した `compose.yaml` を次のように修正します。

```yaml:compose.yaml
services:
  nginx:
    image: docker.io/nginx:stable
    ports:
      - "${WEB_PORT:-8000}:80"
```

ホストへのバインドポート定義を `8000` から `${WEB_PORT:-8000}` に変更しました。

これは以下を意味します。

- `WEB_PORT` 変数が設定されていたらその値をバインド
- `WEB_PORT` 変数が未定義なら 8000 番をバインド

`WEB_PORT` 変数は同名の環境変数で設定することもできますし、**同じ階層のファイル `.env` に定義する** ことも可能です。 

```text:.env
WEB_PORT=8888
```

このように、Compose ファイル中に変数を定義して動的に値を差し替える機能を **Interporation** と呼びます。

https://docs.docker.com/reference/compose-file/interpolation/

Interporation にはいくらかの変数の設定方法があります。詳しくは上記ドキュメントをご参照ください。


#### 方法 2：ホストへのポートバインドをやめる

動的なポート変更では対応できないケースがあります。

SNS マネジメントツールを開発する SocialDog では、サービスの性質上 OAuth を使った連携処理が多く実装されており、ローカルの開発環境でも HTTPS エンドポイントを使えると都合がよいです。

つまり、必然的に 443 番ポートを変更せずそのまま使いたくなります。**複数の環境で同じポート番号を使う**にはどうすればよいでしょうか。

同じ IP アドレス上で複数のプロセスが同じポート番号をバインドすることはできません。[^port-1][^port-2]
ならば**ホストへのポートバインドをやめればよいのです**。

もちろんホストへのポートバインドをやめるということは、ホストからコンテナサービスに直接アクセスできなくなります。そこで、**踏み台となるプロキシサーバーをコンテナ環境のネットワークに参加させる**ことで、プロキシ経由でアクセス可能にします。

[^port-1]: 同じ IP アドレスとポート番号の組み合わせでも、TCP と UDP の各ポートは別物として扱われます
[^port-2]: [SO_REUSEPORT](https://man7.org/linux/man-pages/man7/socket.7.html#:~:text=integer%20boolean%20flag.-,SO_REUSEPORT,-\(since%20Linux%203.9) の利用など特殊な条件は考えないものとしています

具体的なやり方を理解するために、まず Compose ファイルのマージについて紹介します。

##### Compose ファイルのマージ

`docker compose` コマンドを実行すると、デフォルトでカレントディレクトリのファイル `compose.yaml` が読み込まれます。[^default-compose-file]

[^default-compose-file]: [`compose.yml`、`docker-compose.yaml`、`docker-compose.yml` もサポートされている](https://docs.docker.com/compose/intro/compose-application-model/#the-compose-file)

それだけでなく、**`compose.override.yaml` という名前のファイルが存在すれば同時に読み込まれます。**[^compose-file][^specify-compose-file]

[^compose-file]: [COMPOSE_FILE 環境変数](https://docs.docker.com/compose/how-tos/environment-variables/envvars/#compose_file) でこれらのデフォルトを上書きできます
[^specify-compose-file]: `-f` フラグで任意の Compose ファイルを指定することも可能です。つまりデフォルトの挙動は `-f compose.yaml -f compose.override.yaml` と同等です

「同時に読み込まれる」と書きましたが、Docker Compose は**複数の Compose ファイルをマージする機能**を提供しています。

https://docs.docker.com/compose/how-tos/multiple-compose-files/merge/

個々の開発者の裁量で Docker Compose の構成をカスタマイズできるよう、`compose.override.yaml` は git のバージョン管理から除外（`.gitignore` に追加）しておくとよいでしょう。ちなみに SocialDog の開発では `compose.override.yaml.sample` というファイルをリポジトリにコミットし、ニーズに合わせた構成オプションを提供しています。

これから実現する**ポートバインドの無効化**も、`compose.override.yaml` 上で定義する想定で紹介します。


##### `ports` 設定の上書き

`compose.override.yaml` に ports 設定をそのまま書くと、「上書き」ではなく「マージ」になります。

つまり、次のような 2 つのファイルがあったとき

```yaml:compose.yaml
services:
  nginx:
    ports:
      - 80:80
```

```yaml:compose.override.yaml
services:
  nginx:
    ports:
      - 8080:80
```

これらをマージした環境は実質的に次の構成と同じになるということです。

```yaml
services:
  nginx:
    ports: # 設定がマージされている
      - 80:80
      - 8080:80
```

しかし今回のケースでは、 **ホストへのポートバインド定義自体をリセットしたい** ので、次のように `!reset null` という[タグ](https://yaml.org/spec/1.2.2/#24-tags)を付与します。^[`!reset []` でもよいです。なお既存のポートバインド定義を上書きしたければ、`!override` を使います]

```yaml:compose.override.yaml
services:
  nginx:
    # ポートバインド設定の削除 
    ports: !reset null
```

##### プロキシ経由でアクセス

ホストへのポートバインドをやめたので、プロキシ経由で当該コンテナへアクセスできるよう、プロキシサーバーコンテナの定義も追加します。ここでは [ubuntu/squid](https://hub.docker.com/r/ubuntu/squid) イメージコンテナを使った例を示します。[^expose][^squid]

[^expose]: 443 ポート を `expose` に指定しなくても動作上は問題ありません。これはメタ情報として扱われ、[コンテナが当該ポートを公開することを示すための一種のドキュメントになります](https://docs.docker.com/reference/dockerfile/#expose)
[^squid]: [Squid](http://www.squid-cache.org/Doc/) は HTTP プロキシを提供します

```yaml:compose.override.yaml
services:
  nginx:
    # ホスト名を設定
    hostname: socialdog.test
    # ポートバインド設定の削除 
    ports: !reset null
    expose:
      - 443
  squid:
    image: docker.io/ubuntu/squid:5.2-22.04_beta
    volumes:
      - ./squid.conf.d:/etc/squid/conf.d:ro
    ports:
      - ${PROXY_PORT:-3128}:3128
    cap_add:
      # ICMP パケット用
      - NET_RAW
```

上記の例では、デフォルトでホストの 3128 番ポートから、`squid` サービスコンテナをプロキシサーバーとして利用できます。

つまり次のような `.env` ファイルを同じ階層に配置すれば、ポート設定を上書きすることができます。

```text:.env
PROXY_PORT=13128
```

補足すると、同一プロジェクトの Docker Compose のサービス（コンテナ）は、明示的に変更しない限り同じネットワークに所属し、サービス名がそのまま[ホスト名](https://ja.wikipedia.org/wiki/%E3%83%9B%E3%82%B9%E3%83%88%E5%90%8D)になります。つまり互いにサービス名を使って IP アドレスを解決できます。
具体的には上記の場合、 `squid` サービスコンテナから、ホスト名 `nginx` を使って `nginx` サービスコンテナの IP アドレスを解決できます。

明示的にホスト名を設定する場合、`hostname` に定義します。

```yaml:compose.override.yaml
services:
  nginx:
    # ホスト名を設定
    hostname: socialdog.test
```

上記の場合、`socialdog.test` で `nginx` サービスコンテナの IP アドレスを解決できます。

この例ではホスト名を[ドメイン名](https://ja.wikipedia.org/wiki/%E3%83%89%E3%83%A1%E3%82%A4%E3%83%B3%E5%90%8D)で設定（例えば `socialdog` ではなく `socialdog.test` で設定）していますが、これはいくつかの点で重要です。

例えば多くの Web ブラウザは「ドメイン名と認識できない文字列」を [URL](https://en.wikipedia.org/wiki/URL) のホスト名として利用できません。ブラウザから当該コンテナへホスト名でアクセスさせるためには、このように **ドメイン名と認識できる文字列を `hostname` に設定しておく必要があります。**

Squid プロキシ（`squid` サービス）の設定例です。

```squid:squid.conf.d/squid.conf
acl CONNECT method CONNECT
acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 443
http_access allow CONNECT SSL_ports
http_access allow Safe_ports
```

HTTPS プロトコルでは通信内容が暗号化されるため、プロキシサーバーは暗号化された通信をそのまま中継する必要があります。そのため、TCP トンネリングを行う [CONNECT メソッド](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Methods/CONNECT) を利用できるように設定しています。

先程説明したように Docker Compose ネットワーク内では、`hostname` で設定したホスト名を使って当該コンテナの IP アドレスを解決できます。
本構成ではプロキシサーバーコンテナを経由して `nginx` サービスに接続しますが、ホスト名は**プロキシサーバーコンテナ上で[名前解決](https://jprs.jp/glossary/index.php?ID=0084)する必要があります。** この点は重要です。

もし SOCKS プロキシを使う場合、プロキシサーバーにホスト名をそのまま渡せる [SOCKS5](https://www.rfc-editor.org/rfc/rfc1928.html) プロキシを利用する必要があります。


なおコンテナサービスに [MySQL](https://www.mysql.com/) や [PostgreSQL](https://www.postgresql.org/) といったデータベースコンテナが含まれる場合、おまけで [Adminer](https://www.adminer.org/) サービスも追加しておくと、環境ごとにデータベースをブラウザから確認できるのでおすすめです。[^adminer]

[^adminer]: もともと [DBeaver](https://dbeaver.io/) を愛用していましたが、[OpenJDK](https://openjdk.org/) が [SOCKS5 でのドメイン名リクエストをサポートしていない](https://bugs.openjdk.org/browse/JDK-8028776)ためこの点で都合が悪かったというのが本音です。ただ Adminer は本当に使いやすいです
  
```yaml:compose.override.yaml
services:
  db:
    image: docker.io/postgres
    environment:
      POSTGRES_PASSWORD: example
    restart: always

  # adminer の定義
  adminer:
    image: docker.io/adminer:latest
    hostname: adminer.test
    restart: always

  # プロキシの定義
  squid:
    image: docker.io/ubuntu/squid:5.2-22.04_beta
    volumes:
      - ./squid.conf.d:/etc/squid/conf.d:ro
    ports:
      - ${PROXY_PORT:-3128}:3128
    cap_add:
      - NET_RAW
```

この例の場合、プロキシ経由のアクセスで  `http://adminer.test:8080` にアクセスすると、Adminer の画面を開くことができ、データベースクライアントとして利用できます。

前述の通り「同じプロジェクト名で管理されるサービスコンテナ間は、互いにサービス名で IP アドレスを解決できる」ので、上記の例では `db` というホスト名で postgres データベースにアクセスできます。

##### 制限

`hostname` に `localhost` といった[ループバック](https://ja.wikipedia.org/wiki/%E3%83%AB%E3%83%BC%E3%83%97%E3%83%90%E3%83%83%E3%82%AF#%E4%BB%AE%E6%83%B3%E3%83%AB%E3%83%BC%E3%83%97%E3%83%90%E3%83%83%E3%82%AF%E3%82%A4%E3%83%B3%E3%82%BF%E3%83%BC%E3%83%95%E3%82%A7%E3%82%A4%E3%82%B9)アドレスを示すホスト名は指定すべきではありません。

ブラウザが認識できるなにかしらのホスト名は指定する必要があるので、[RFC 2606](https://www.rfc-editor.org/rfc/rfc2606.html) で予約されている `.test` トップレベルドメインを利用するなどを推奨します。

なお、 **複数の Compose 環境間で同一の `hostname` を設定しても問題ありません。** 各プロキシサーバーコンテナからアクセスできるサービスは、プロジェクト名ごとに環境が分離されるため、接続するプロキシサーバーコンテナを変えれば、アクセスできるサービスもまた変わるためです。

ただ、繰り返しになりますが「プロキシに名前解決させる」ことに留意する必要はあります。

##### 注意

プロキシ経由でコンテナへアクセスすることは、一種の複雑性を持ち込むことになります。

プロキシの設定やプロキシを扱うソフトウェア側のバグなどによっても、「動作するはずのコードが動作しない」ということがおきえます。

**何か動作がうまくいかないときは、一度通常通りの構成でデバッグすることを強くおすすめします。**

## `.env` による環境分離

前述の `.env` ファイルによるポート設定は、もちろんプロジェクト名と一緒に設定できます。

```text:.env
COMPOSE_PROJECT_NAME=some-project
PROXY_PORT=13128
```

- コンテナ環境はプロジェクト名で分離する
- ホストへのバインドポートはプロキシポートだけ使い分ける

`compose.override.yaml` は共通の定義を利用し[^ln]、
上記の設定は `.env` ファイルで区別するだけで、**環境を分離しながら Compose 環境を複数立ち上げられるようになります。**

[^ln]: 筆者はワークツリー間で共通の `compose.override.yaml` を配置する際、`cp` ではなく [`ln` コマンド](https://man7.org/linux/man-pages/man1/ln.1.html)で[ハードリンク](https://ja.wikipedia.org/wiki/%E3%83%8F%E3%83%BC%E3%83%89%E3%83%AA%E3%83%B3%E3%82%AF)を作成し、変更が同期されるようにしています

## プロキシの利用例

開発で役立つプロキシサーバーの設定例を紹介します。

### Playwright MCP

Playwright MCP サーバーの起動時引数でプロキシを設定することができます。
次は Claude Code での設定例です。

```json:.mcp.json
{
  "mcpServers": {
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": [
        "@playwright/mcp",
        "--proxy-server",
        "http://127.0.0.1:13128"
      ],
      "env": {}
    }
  }
}
```

プロキシサーバーの接続先を変えれば、別の Compose 環境に接続できます。つまり **Claude Code を並列実行しても環境が衝突しません。**

### Chromium での設定例

macOS の場合、[Chrome](https://www.google.com/intl/ja_jp/chrome/) だと（macOS の）システム設定上のプロキシを利用する必要があります。

代わりに [Chromium](https://www.chromium.org/Home/) をインストール[^ungoogled-chromium]し、コマンドラインから任意のプロキシを設定して起動すると便利です。

```bash
# Chromium のインストール（macOS の場合）
brew install --cask ungoogled-chromium
```

[^ungoogled-chromium]: もともと `brew install --cask chromium` で記事を執筆していましたが、[2025/7/27 に deprecated になったようです](https://github.com/Homebrew/homebrew-cask/pull/221570/commits/fad7421b6694e57b1f49c6b4e33a52e2204034c0)

`--proxy-server` オプションでプロキシサーバーを指定できます。

```bash
/Applications/Chromium.app/Contents/MacOS/Chromium \
  --user-data-dir=.chromium-profile \
  --proxy-server=http://127.0.0.1:13028 \
  https://socialdog.test # hostname で指定したドメイン名を使うこと
```

例のように `--user-data-dir` を指定すると、当該ディレクトリにプロフィール情報を保存できます。具体的には、ブックマークや保存したパスワードなどを次回起動時にも引き継ぐことができます。こちらも環境ごとに分けておくと便利です。

### Firefox での設定例

```bash
# Firefox のインストール（macOS の場合）
brew install --cask firefox
```

[Firefox](https://www.firefox.com/) の場合、`--profile` オプションでプロフィール情報を保存するディレクトリを指定できます。

```bash
/Applications/Firefox.app/Contents/MacOS/firefox \
  --profile .firefox-profile \
  --no-remote \
  https://socialdog.test # hostname で指定したドメイン名を使うこと
```

Firefox はプロキシをコマンドラインから指定できず、設定画面上でプロキシを設定する必要があります。

次は HTTP プロキシを設定する例です。

![](https://storage.googleapis.com/zenn-user-upload/615152e16258-20251018.png)

### Safari でのプロキシ利用

筆者の調べた限りですが、残念ながら [Safari](https://www.apple.com/jp/safari/) では任意のプロキシをブラウザインスタンスごとに指定することができないようです。

macOS の場合、[システム設定でプロキシを設定する](https://support.apple.com/ja-jp/guide/mac-help/mchlp25912/mac)必要があります。

## おまけ：Podman の活用

本環境の動作確認は [Podman Desktop](https://podman-desktop.io/) を使った docker compose 環境で行いました。

[Podman](https://docs.podman.io/) はコンテナ管理のための中央集権的なデーモンプロセスがないため [^podman] フットプリントが軽く複数立ち上げに適していると感じています。

[^podman]: 仮想マシン上でコンテナサービスを立ち上げホストから接続する場合や docker compose を使う場合、[API 待ち受け用のデーモンプロセス](https://docs.podman.io/en/latest/markdown/podman-system-service.1.html)は必要です

## 他

環境を複数用意するにしても、環境構築の手間は都度発生します。

こちらについては [Makefile](https://www.gnu.org/software/make/manual/make.html) を使って、あらゆる依存関係を自動で解消する Tips についても以下記事で紹介してますのでぜひご参考ください。

https://zenn.dev/na0x2c6/articles/buff-your-development

SocialDog でも、例えば以下を 1 つのコマンドで用意できるように工夫しています。

- コンテナ環境のビルド
- [yarn](https://yarnpkg.com/) による依存系のインストール
- データベースのマイグレーション
- [Composer](https://getcomposer.org/) による依存系のインストール
- [1Password CLI](https://developer.1password.com/docs/cli/) を使ったシークレットファイルのダウンロード

## あとがき

最近 [Django](https://www.djangoproject.com/) の共同開発者である [Simon Willison](https://en.wikipedia.org/wiki/Simon_Willison) 氏が [Vibe engineering](https://simonwillison.net/2025/Oct/7/vibe-engineering/) というブログ記事を投稿されていました。
こちらの中で、次の一文が印象的でした。

> AI tools **amplify existing expertise**. The more skills and experience you have as a software engineer the faster and better the results you can get from working with LLMs and coding agents.

_[Claude Sonnet 4.5](https://docs.claude.com/en/docs/about-claude/models/whats-new-claude-4-5) による邦訳：_

> AIツールは **既存の専門知識を増幅させます**。ソフトウェアエンジニアとしてのスキルと経験が豊富であればあるほど、LLMやコーディングエージェントと協働することで、より速く、より良い結果を得ることができます。

本記事を書くにあたっても、AI を使って開発を効率化するために、既存の技術を深く知り応用を考えることは改めて重要だと思いました。

よきコーディングライフを。
