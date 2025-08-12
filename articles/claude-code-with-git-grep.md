---
title: "Claude Code で git-grep を使うと幸せになれる、かもしれない"
emoji: "😸"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [claudecode,git]
published: true
publication_name: socialdog
---


私たちのチームでは 6 月から全面的に Claude Code を使った開発をスタートしています。

https://x.com/na0x2c6/status/1930386098058113182

本記事では筆者が 2 ヶ月間 Claude Code を触りながら行き着いた、シンプルながら効果的な [git-grep](https://git-scm.com/docs/git-grep/ja) の使い方を紹介します

## この記事で書くこと

- Claude Code で git-grep を活用する例
- （おまけ）新しいフックを追加するときの Tips

## この記事で書かないこと

- フック定義（python コード）の解説
- Claude Code やフックの説明

## git-grep を PreToolUse フックで使う

いきなり結論ですが、[PreToolUse フック](https://docs.anthropic.com/ja/docs/claude-code/hooks#pretooluse)で Grep ツールの呼び出しを禁じ、 **`git grep --function-context`を強制するフック** を定義しています。

@[gist](https://gist.github.com/na0x2c6/ebf2c1ffd7cf0681c5d7d9dcfff79b6e)

もちろん Bash ツールで grep を使ったコンテンツ検索も禁じています。ripgrep も断固として禁じています。

@[gist](https://gist.github.com/na0x2c6/e69ee11e51795ad6e7c25ea5cb686a21)

なおフックの python コードは [Claude Code のドキュメント](https://docs.anthropic.com/en/docs/claude-code/hooks#exit-code-example%3A-bash-command-validation) を少し改変して利用しています。

### git-grep の何がよいのか

LSP サーバー[^lsp] を使うよりフットプリントが小さく、また後述のフラグ利用でコード調査をスムーズに進められる利点があります。

[^lsp]: [MCP サーバー](https://modelcontextprotocol.io/docs/getting-started/intro)経由で利用。最近人気の [serena](https://github.com/oraios/serena) でも利用されている

思想が強いのは否定しません。

### `--function-context` と `--show-function`

そのまま git-grep を使うのではなく、 基本は `--function-context` フラグも利用します。

```python
    (
        lambda cmd: cmd.strip().startswith("grep "),
        "grep の変わりに git grep --function-context [--and|--or|--not|(|)|-e <pattern>...] -- <pathspec>... を使ってください。--function-context フラグにより出力行が多すぎる場合、 --show-function と -C フラグを利用してください",
    ),
    # ...
    (
        lambda cmd: (
        re.match(r"^git\s+grep\s+", cmd) and
        not re.search(r"-W|-p|--function-context|--show-function", cmd)
    ),
    "git grep では --function-context か --show-function フラグを使ってください。まず --function-context フラグを利用し、結果行が多すぎる場合、 --show-function と [ -C | -A | -B ] フラグを利用してください",
    ),

```

`--function-context` フラグは、マッチしたパターンを含む **関数全体** を grep 結果に出力します。

つまり、調べたい関数やコンポーネント検索したとき、**その使われ方** と一緒に確認することができます。

![--function-context 利用サンプル](https://storage.googleapis.com/zenn-user-upload/58419d10ce69-20250807.png)
*引用：[facebook/react](https://github.com/facebook/react)*

これを Claude Code に使わせることで、Claude Code に任意の関数やコンポーネントの使い方を効率よく調べさせることができます。

ただこの「関数全体を出力する」機能はときに出力サイズが大きくなるので、`--show-function` フラグも許容しています。こちらは関数全体ではなく、マッチしたパターンと **関数名** を出力します。

![--show-function 利用サンプル](https://storage.googleapis.com/zenn-user-upload/80eded1822a7-20250807.png)
*引用：[facebook/react](https://github.com/facebook/react)*

なお `--function-context` フラグの省略表記で `-W` が、`--show-function` フラグでは `-p` が使えますが、Claude Code がより意図を理解してくれる気がするのであえて長いフラグを使っています。

## 独自のフックを定義する Tips

筆者は [WebFetch ツール用のフック](https://gist.github.com/na0x2c6/32cc9edfc10d505f27a2a12f850029bd) も定義しています。

当時 WebFetch でどういった json 入力がフックに与えられるかがわからず、ドキュメントや Web 上でも見つけられなかったので、独自で調べる必要がありました。

現時点ではベストプラクティスがあるかもしれませんが、簡単に json の形式を確認する Tips を紹介します。

結論からいうと次のようなコマンドを使います。


```sh
jq . ~/.claude/projects/*/*.jsonl | grep -C 10 WebFetch | less
```

簡単に解説すると、 `~/.claude/projects/` 配下には、ワークスペース（Claude Code を起動したディレクトリ）ごとにディレクトリが作成されます。

`~/.claude/projects/<ワークスペース用ディレクトリ>/` 配下には、セッションごとに [jsonl](https://jsonlines.org/) ファイルで、ユーザーと Claude Code がやりとりしたプロンプトデータが保存されています。

上記コマンドでは、これらを `jq` コマンドで整形してから `grep` で任意のツール（上記例では WebFetch）の周辺行を確認しています。

![WebFetch の json 抜粋](https://storage.googleapis.com/zenn-user-upload/193fa69f0229-20250805.png)
*`jq . <jsonl ファイル> | grep WebFetch -C 10` の例*

この例では `url` という入力があることがわかります。これをフックで検証に利用することができます。

```py
# JSON 読み込み
try:
    input_data = json.load(sys.stdin)
except json.JSONDecodeError as e:
    print(f"Error: Invalid JSON input: {e}", file=sys.stderr)
    sys.exit(1)

tool_name = input_data.get("tool_name", "")
tool_input = input_data.get("tool_input", {})

# jsonl 上で入力 `url` を確認したので、これを読み込んで検証に利用
url = tool_input.get("url", "")
issues = validate_url(url)

```

## あとがき

本記事で紹介した効果は筆者の _経験に基づく感覚であり、計測したものではない_ ということにご留意ください。

_クセのある Claude Code の使い方をネタとして紹介したかった_ という動機で書き始めた記事でした。

ただ git-grep はとても高機能であり、**人間が使う上でも役立つ** 場面が多いので、もし参考になれば幸いです。
