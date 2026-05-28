---
title: "きみは GitClear を知っているか 〜AI ROI をデータドリブンに分析する〜"
emoji: "📊"
type: "idea"
topics: ["git", "roi", "開発生産性", "okr", "ai"]
published: true
publication_name: "socialdog"
---

## はじめに

SocialDog が公開する情報ポータルやスライド資料には「GitClear」「Diff Delta」という見慣れない単語が現れます。

![SocialDog 情報ポータル/会社制度/人事制度（等級・報酬・評価）/OKRについて](/images/do-you-know-git-clear__info-portal-okr.png)
*[SocialDog 情報ポータル/会社制度/人事制度（等級・報酬・評価）/OKRについて](https://portal.socialdog.jp/OKR-25ac961b7be2415797672839ec00e873)*

![SocialDog 情報ポータル/採用情報 - 3分でわかる会社紹介資料](/images/do-you-know-git-clear__recruit-slide.png)
*[SocialDog 情報ポータル/採用情報 - 3分でわかる会社紹介資料](https://portal.socialdog.jp/recruit)*


GitClear は開発生産性を可視化するサービスです。

https://www.gitclear.com/

日本であまり知られていませんが、[GitLens](https://www.gitkraken.com/gitlens) で有名な [GitKraken](https://www.gitkraken.com/) のサービス[GitKraken Insights](https://help.gitkraken.com/gk-dev/gk-dev-insights/) の分析エンジンも GitClear が提供しています。

SocialDog は 2023年5月から 3 年に渡って GitClear を利用しています。私は日本でもっと知られていいサービスだと考えており、この記事では GitClear について紹介します。

:::message
本記事はプロモーションではありません。また会社を代表する意見ではなく、GitClear の提案・導入・運用を一人のチームリーダーとして主導した立場からの意見であることにご留意ください
:::

## この記事で書くこと

- GitClear の紹介
- GitClear が提供する指標「Diff Delta」の紹介
- SocialDog での GitClear の利用事例の紹介

## この記事で書かないこと

- GitClear 以外の開発分析系サービス・ツールとの詳しい比較

## GitClear

https://www.gitclear.com/

GitClear は [GitHub](https://github.com/) / [GitLab](https://about.gitlab.com/) / [Bitbucket](https://bitbucket.org/) / [Azure DevOps](https://azure.microsoft.com/en-us/products/devops) といった主要な Git ホスティングサービスと連携し、開発生産性の分析に役立つメトリクスを提供するツールです。

GitClear の CEO である [Bill Harding 氏](https://leaddev.com/community/bill-harding) はオンラインマーケットプレイスの [Bonanza.com](https://www.bonanza.com/about_us) の CEO であった 2016 年に、開発の進捗を効果的に追跡するための構想を始め、2019 年に GitClear を正式リリースしました。

GitClear はもともと Bonanza.com の開発のために生まれました[^geekwire][^gitclear-about]。後述しますが、非常にデータドリブン [^data-driven] な考え方でサービスが提供されています。

[^geekwire]: [Static Object tracks the progress of programmers by focusing on the 5% of code that's meaningful – GeekWire](https://www.geekwire.com/2018/git-clear/) や [About GitClear](https://www.gitclear.com/about) で読める。
[^gitclear-about]: [About GitClear - GitClear](https://www.gitclear.com/about)
[^data-driven]: ここでは計測したデータに基づき意思決定・課題解決を行うこと

## Diff Delta

GitClear で特に特徴的なのは、**Diff Delta** という独自に設計された指標です。

https://www.gitclear.com/help/technical/diff_delta_calculation

Diff Delta は次のように説明されています。

> Diff Delta is the foundational metric GitClear employs to interpret "how much meaningful change is occurring" in a repo over time.
> _Diff Delta は、リポジトリで時間の経過とともに **「どれだけ意味のある変更が発生しているか」** を解釈するために GitClear が採用している基盤的な指標です。_

ここで述べられている **「意味のある変更」** というのが慎重に設計されていると考えています。

まず Diff Delta がどういうものかをイメージできるよう、簡単に紹介していきます。[^dd-factors]

[^dd-factors]: 詳しい式の解説は [Diff Delta factors - GitClear](https://www.gitclear.com/diff_delta_factors) を参照されたい

### Diff Delta の計測方法

GitClear は **「第一原理思考（first principles）」** で機能を設計しており、この考え方は以下の記事で解説されています。

https://www.gitclear.com/help/understand_diff_delta_from_first_principles_stats_on_metric_stability

簡単に説明すると第一原理思考とは、「これ以上推測の余地がない前提を使って考える」ことで、語弊を恐れずにいうと **「データドリブンな考え方」** とも言えます。　

上記の記事では[コード行数](https://en.wikipedia.org/wiki/Source_lines_of_code)、コミット数、プルリクエスト数といった指標はブレ幅が大きく、判断指標とするにはノイズが大きいとされます。

Diff Delta は次に紹介する計測方法を使って、ノイズを減らした「意味のある変更」を計測しています。

#### コードの追加

![](/images/do-you-know-git-clear__diffdelta-add.png)
*引用: [Diff Delta Explained: Calculation, Operations and Idioms - GitClear](https://www.gitclear.com/help/technical/diff_delta_calculation)*

コードを新しく追加したときに加算されます。ポイントは実際に追加された文字数などによって変わります。

「コードを追加する」ことは「保守すべきコードを増やす」ことでもあるため、**一度に多くの行を追加すると、同じコード量に対するスコアは小さくなります。**

#### コードの削除

![](/images/do-you-know-git-clear__diffdelta-delete.png)
*引用: [Diff Delta Explained: Calculation, Operations and Idioms - GitClear](https://www.gitclear.com/help/technical/diff_delta_calculation)*

コード追加は一行あたり最大 10 ポイントの Diff Delta が計上されるのに対し、コードの削除は一行当たり最大 25 ポイントが計上されます。

コードの削除は保守すべきコードベース全体を小さく保つ = 保守コストを下げるとみなされ、**コードの追加よりもスコアが高く設定されています。**

#### コード移動

![](/images/do-you-know-git-clear__diffdelta-move.webp)
*引用: [Diff Delta Explained: Calculation, Operations and Idioms - GitClear](https://www.gitclear.com/help/technical/diff_delta_calculation)*

コードを別の場所に移動するだけの差分です。**Diff Delta として計上されません。**

#### コードの変更

![](/images/do-you-know-git-clear__diffdelta-update.webp)
*引用: [Diff Delta Explained: Calculation, Operations and Idioms - GitClear](https://www.gitclear.com/help/technical/diff_delta_calculation)*

部分的な調整・修正を含んだコードです。

**古いコードを変更したときほどコンテキストの理解に労力が必要とみなされスコアが大きくなります。**

空白やタブ文字のみの修正など、一部の変更は Diff Delta に計上されません。また関数名の変更などにともなう複数個所の差分は、後述の「検索と置換」による変更として扱われます。

#### 検索と置換

![](/images/do-you-know-git-clear__diffdelta-replace.png)
*引用: [Diff Delta Explained: Calculation, Operations and Idioms - GitClear](https://www.gitclear.com/help/technical/diff_delta_calculation)*

3 箇所以上の一貫したパターンの置換は「検索と置換」とみなされます。

#### コピーアンドペースト

![](/images/do-you-know-git-clear__diffdelta-copy-and-paste.png)
*引用: [Diff Delta Explained: Calculation, Operations and Idioms - GitClear](https://www.gitclear.com/help/technical/diff_delta_calculation)*

複数のコミットで同じパターンの行追加が行われた場合、コピーアンドペーストとみなされ、**Diff Delta は計上されません。**

#### 何もしていない変更

![](/images/do-you-know-git-clear__diffdelta-noop.png)
*引用: [Diff Delta Explained: Calculation, Operations and Idioms - GitClear](https://www.gitclear.com/help/technical/diff_delta_calculation)*

空行追加、空白文字種別の変更などは No-ops（何もしていない）とみなされ、**Diff Delta に計上されません。**

#### 言語の検出

本記事執筆時点で 40 余りある言語を検出し、**言語間のスコアは正規化されます。**

https://www.gitclear.com/help/general/languages

例えばコードブロックにブレース（`{` と `}` ）が必要な言語や、import / include 文を多用するような言語であっても、これらによってスコアが優位にならないよう調整されています。

また同じ言語間であっても、次のような**コードスタイルの違いで Diff Delta に差異は生まれません。**

- 改行が多い・少ない
- コメント行数が多い・少ない

#### コンテキストの考慮

例えば以下の 2 つを比べます。i. で書く **10 行の追加** と、ii. の **1 行の修正** とでは、どちらの方が開発者にとって負担が大きいでしょうか。

i. `if (x >= 0) { .... }` のような if 文のコード 10 行を新規実装したとき
ii. `if (x > 0)` の条件を `if (x >= 0)` に修正することでバグを直したとき

Diff Delta では ii. のような **「単独の変更」** は、コードの前後関係の理解や挙動の検証などに負担がかかるとみなし、**複数行を新規追加したときに比べ、1 行当たりのスコアが大きく計上されます。**

また、Code Churn （一定期間内に破棄されたコード）は「価値を生んでいない」とみなされ、**Diff Delta の計上から外されます。**

つまり次のようなケースでは、すぐに破棄された X の修正分は Diff Delta に計上されず、「A と B で Y の修正を行った」とみなされます。

1. コミット A で X の修正を追加した
2. A に続くコミット B で、X を書き直して Y にした

他にも **ファイルの種類によって Diff Delta スコアのスケーリングを調整できます。**

例えば次のようなファイルの違いによって、コード一行あたりの価値が変わると考えることは自然だと思います。

- CSS（`*.css`）と Python（`*.py`）
- 実コード（例： `*.ts` や `*.go`）とテストコード（例：`*.test.ts` や `*_test.go`）

このため、ファイルごとに任意のスカラー係数を設定し、Diff Delta スコアの増え方を調整することができます。[^diffdelta-scale]

![Code Domoins 設定](/images/do-you-know-git-clear__config-code-domains.png)
*引用: [Configuring and using Code Domains - GitClear](https://www.gitclear.com/help/general/configuring_and_using_code_domains)*

[^diffdelta-scale]: デフォルトでも設定されており、生成コードや `package-lock.json` などのファイルは Diff Delta が計上されないようになっています。

### ゲーミング耐性

Diff Delta のベロシティ（期間あたりの Diff Delta 増加量）を上げるためには **「意味のあるコードの追加・修正・削除を一定以上のパフォーマンスで行い続ける」** ことが求められます。

このベロシティは GitClear 上で個人、チーム、組織全体それぞれのスコープで確認したり、ディレクトリ単位でも確認できます。

![リポジトリ単位の Delta per hour（ベロシティ）を一覧で確認できる](/images/do-you-know-git-clear__velocity-browse-repos.png)
*引用: [Tech Debt Inspector - GitClear](https://www.gitclear.com/help/tech_debt_inspector_list_directories_by_developer_velocity)*

[Tech Debt Inspector](https://www.gitclear.com/help/tech_debt_inspector_list_directories_by_developer_velocity) ではこの「ベロシティの低いフォルダ」を調べることができます。

![Tech Debt Inspector でベロシティの低いディレクトリを表示する](/images/do-you-know-git-clear__tech-debt-inspector.png)
*引用: [Tech Debt Inspector - GitClear](https://www.gitclear.com/help/tech_debt_inspector_list_directories_by_developer_velocity)*

例えば「このディレクトリは開発が継続しているけどベロシティは他に比べて低いな」という気づきを得られます。

ここから「ベロシティを高くしたい」「継続的に一定の意味あるコードをコミットしたい」という動機に繋がり、「コードべースの健全性を高めよう」という動機にまで昇華することができればリファクタリングの優先度判断に繋げることもできます。

しかもその優先度は計測されたノイズの少ないデータを元に判断することができるということです。

[グッドハートの法則](https://ja.wikipedia.org/wiki/%E3%82%B0%E3%83%83%E3%83%89%E3%83%8F%E3%83%BC%E3%83%88%E3%81%AE%E6%B3%95%E5%89%87)では、「ある尺度が目標として掲げられたとき、それはよい尺度ではなくなる」と言われますが、Diff Delta は目標の指標（ゲーミング指標）掲げられたとしても、コードベースに対してポジティブな影響を与えるように設計されており、GitClear はこれを「ゲーミング耐性（gaming-resistant）がある」と表現しています。[^game-resis]

[^game-resis]: [Measuring Code Activity: A Comprehensive Guide for the Data Driven - GitClear](https://www.gitclear.com/measuring_code_activity_a_comprehensive_guide_for_the_data_driven)

## GitClear の良さ

開発生産性を分析するためのツールやサービスを調査していたとき、重要視していたのは以下の 3 つでした。

1. データドリブンに考えられているか
2. 実績があるか
3. コスト感が妥当か

前述の通り、GitClear は「第一原理思考」で考えてサービスを開発しており、その点に惹かれました。

また 2016年から構想され、正式リリースまでに3年かけており、この間 Bonanza.com の開発チームで運用されていたということで、実務ベースの実績があると考えました。
そして SocialDog の開発チームで 2 週間ほどのトライアルを経て実際に有用だと判断し正式導入することを決めました。[^sd-trial]

2023 年導入当時は、GitClear の導入事例は正直あまり紹介されていなかったと記憶してますが、この3年でエンタープライズ向けに採用される事例が増えているようです。

例えばアメリカの医療 IT 大手で 700 名規模の開発組織を擁する [NextGen Healthcare](https://www.gitclear.com/case_studies/nextgen_healthcare) で採用されています。

他にも 400 名規模の開発組織を擁し、[2025年に「世界最高のデジタル銀行（World’s Best Digital Bank）」という賞を受賞](https://georgia.lu/bank-of-georgia-crowned-worlds-best-digital-bank-for-the-second-year-in-a-row/)した[ジョージア銀行](https://bankofgeorgia.ge/en/about)は、[GitClear が開発パフォーマンスの分析・改善に寄与した](https://www.youtube.com/watch?v=9iblBptYGPU)そうです。

課金体系はユーザー単位での課金で、組織・リポジトリ規模に応じたプランがあります。

https://www.gitclear.com/pricing

SocialDog の規模感（20 名程度）であれば、競合サービスの中でも比較的安く、以前に利用していたサービスよりも半額程度の運用コストになりました。[^gitclear-cost]

また課金単位は「コミットを push したユーザー（データ集計対象とするコミッター）」ごとのため、開発に参加しないマネージャーなどは無料でレポートを見られるのがありがたいです。

[^sd-trial]: Twitter（現 X）のAPI 制限騒動の最中で熟考したと言えなかったかもしれませんが、機能はわかりやすく不明瞭なことはなかったのでそのまま導入に進みました。
[^gitclear-cost]: ドル払いのため為替の変動を受けます

## SocialDog での活用

SocialDog は GitClear をどのように活用してきたかを紹介します。

### OKR

SocialDog は半期ごとに OKR を設定します。[^sd-okr]

各開発チーム・メンバーは半期ごとに何にフォーカスしたいかを考え、開発に集中したい場合は Diff Delta の目標を掲げています。

Diff Delta の他にもプルリクエスト作成数や Cycle Time ^[cycle-time] なども同時に Key Result に掲げ、全体として開発の目標を設定するようにしていますが、これらの KPI も GitClear 上で確認することができます。

![Pull Request Cycle Time をリポジトリ別に確認できる](/images/do-you-know-git-clear__pr-cycle-time.png)
*引用: [Pull Request Classic Stats - GitClear](https://www.gitclear.com/help/pull_request_classic_stats_how_to_optimize_long_term_health)*

なお GitClear は以下の記事で、ソフトウェアエンジニアリングにおける KPI の種類と考え方について解説しており、しばしば Key Result を考えるうえで参考としています。

https://www.gitclear.com/five_best_engineering_kpis_and_how_they_get_cheated

[^sd-okr]: [SocialDog 情報ポータル/会社制度/人事制度（等級・報酬・評価）/OKRについて](https://portal.socialdog.jp/OKR-25ac961b7be2415797672839ec00e873)
[^cycle-time]: プルリクエストを作成した最初のコミットが push されてから当該プルリクエストがメインブランチにマージされるまでの平均時間

### 声掛けタイミングの見極め

[Commit Activity Browser](https://www.gitclear.com/help/quick_start_guide_cab) という機能では、コミットごとの Diff Delta が時系列でバルーンの形で可視化されます。

https://www.gitclear.com/help/commit_group_pattern_screenshots

![Commit Activity Browser でコミットがバブルで時系列に可視化される](/images/do-you-know-git-clear__cab-overview.png)
*引用: [Commit Activity Browser - GitClear](https://www.gitclear.com/help/quick_start_guide_cab)*

この画面で観察できるバブルは、コミットの作り方を直感的に理解するのに役立ちます。

ヘルプページに紹介される例をいくつか抜粋します：

![Distraction-heavy to distraction-free programming](/images/do-you-know-git-clear__cab-distraction-free.jpg)
*引用: [Commit Group Pattern Screenshots - GitClear](https://www.gitclear.com/help/commit_group_pattern_screenshots)*

→ 差し込みが多かったが開発に集中できるようになった


![Product launch => Quick bugfixing => Hard bugfixing](/images/do-you-know-git-clear__cab-product-launch.jpg)
*引用: [Commit Group Pattern Screenshots - GitClear](https://www.gitclear.com/help/commit_group_pattern_screenshots)*

→ プロダクトリリース後に細かな不具合修正に取り組み、その後難しい修正になった


![Developer obsessing over a poorly understood topic](/images/do-you-know-git-clear__cab-obsessing.jpg)
*引用: [Commit Group Pattern Screenshots - GitClear](https://www.gitclear.com/help/commit_group_pattern_screenshots)*

→ 理解不足の機能修正に沼っており、修正とコミットを繰り返している

![Senior developer working on a well-defined feature in a system they understand](/images/do-you-know-git-clear__cab-senior-developer.jpg)
*引用: [Commit Group Pattern Screenshots - GitClear](https://www.gitclear.com/help/commit_group_pattern_screenshots)*

→ シニアエンジニアが仕様の明確な開発に取り組んでいる。理想的なパターン。

このように、バブルパターンを見ると、開発に集中できているのか、悩んでいるのか、不具合修正が続いているのかなどに直感的に気づくことができ、チームやマネージャーが必要なアクションを取りやすくなります。

### オンボーディング

[Cohort Report](https://www.gitclear.com/help/cohort_report_new_developer_onboard) は「開発に参加し始めてからの Diff Delta の推移」を個人ごとに見ることができます。

例えば、「2024年1月に開発に参加した A さんの 2024年3月時点」と、「2026年3月に参加したBさんの2026年5月時点」で比較できる（開発に参加してから2ヶ月後時点同士で比較できる）ということです。

![Cohort Comparison: 過去に参加した開発者と同期間でのオンボーディング進捗を比較する](/images/do-you-know-git-clear__cohort-report.png)
*引用: [Cohort Report - GitClear](https://www.gitclear.com/help/cohort_report_new_developer_onboard)*

なおこのレポートは心理面に配慮されており、閲覧は当該ユーザーの承認を得る必要があります。

### DORA 指標の確認

開発で必須とも言える計測指標の[Google DORA メトリクス](https://cloud.google.com/blog/ja/products/gcp/using-the-four-keys-to-measure-your-devops-performance) は当然網羅しており、Four Keys を確認することができます。

![DORA タブで Release Count などの Four Keys を確認できる](/images/do-you-know-git-clear__dora-release-count.png)
*引用: [Google DORA Practical Implementation Guide - GitClear](https://www.gitclear.com/help/google_dora_practical_implementation_guide)*

なお Four Keys  に限りませんが、 GitClear の集計に使われる時間指標は、各開発者のコミット時刻などから業務時間を推定して計算されるそうです。[^time-est]

https://www.gitclear.com/help/estimating_time_used_per_commit

例えば次のケースでは、レビュー待ちの時間はほぼゼロとして扱われます。

1. A さんが業務終了時間ギリギリにプルリクエストを作成
2. 翌日、Bさんが勤務開始直後に当該プルリクエストをレビュー

[^time-est]: 指標の性質上、Four Keys のサービス復元時間（Time to Restore Services）の計算に使われる時間については、業務時間は考慮されず、純粋な経過時間によって計算されます

## その他良かったこと

### リファクタリング

Diff Delta を OKR の指標に取り入れることで、リファクタリングが自発的に行われるようになりました。

特にコード削除はスコアが大きめに設定されているため、「使わなくなったフラグや古いコードを消すチャンスがあれば積極的に消す」という動機づけに繋がっています。

### スキルへの投資と開発を進めるバランスの参考になる

一定の Diff Delta を目標として掲げ達成を目指すことを考えます。

このとき、「Diff Delta を効率よく上げる」ためには「よく理解している技術領域で開発に貢献する」という動き方になります。

逆に「Diff Delta のベロシティに余裕がある」ときは、「新しい技術領域にチャレンジしてみよう」という行動に繋げやすくなります。

このように、開発とチャレンジのバランスを、客観的な根拠をもって取りやすくなりました。

なお、[Domain Experts レポート](https://www.gitclear.com/help/domain_experts_report) では、「どのメンバーがどの技術領域に多くコミットしているか」を確認することができ、「新しく触るコードを誰に相談すればいいか」を判断する上での参考にできます。

![Domain Experts レポート: Code Domain ごとに最も詳しい開発者を一覧で確認できる](/images/do-you-know-git-clear__domain-experts.png)
*引用: [Domain Experts Report - GitClear](https://www.gitclear.com/help/domain_experts_report)*

### サポート対応が速い

問い合わせや改善要望へのレスポンスがとても速く、改善要望やバグ報告に対する修正が数日のうちにリリースされることもありました。この点は安心できましたし、カジュアルにフィードバックを伝えられることにも繋がっています。

## AI 時代の GitClear

### ROI の変化を確認する

AI を使った開発が当たり前になりましたが、AI 利用には安くはないコストも発生します。

「AI を開発に使っているが、実際 ROI（Return on Investment、投資利益率）は実際どうなんだ」という疑問は当然でてくると思いますが、GitClear は ROI を確認するための機能を着実に増やしています。

https://www.gitclear.com/help/calculating_ai_roi_per_line_with_usage_cohorts_and_directory_breakdown

例えば AI のヘビーユーザー・通常ユーザー・非利用者で生産性と品質指標を比較できる [AI Cohort Stats](https://www.gitclear.com/help/ai_cohort_stats_overview) 機能や、AI の生成コードが Code Churn や重複コードの増大にどう影響しているか分析できる機能を提供しています。

![Diff Delta by AI Cohort: AI 利用度ごとに Diff Delta の推移を比較できる](/images/do-you-know-git-clear__ai-cohort-diff-delta.png)
*引用: [AI Cohort Stats Overview - GitClear](https://www.gitclear.com/help/ai_cohort_stats_overview)*

AI の生成コードは[GitHub Copilot / Cursor / Claude Code 等で集計可能](https://www.gitclear.com/help/ai_measurement_github_copilot_usage_metrics)です。

ちなみに [Claude Code](https://code.claude.com/docs/ja/overview) のテレメトリ集計は、[Hooks](https://code.claude.com/docs/ja/hooks) を使って計測するのですが、この Hooks の最初の利用者は SocialDog の開発チームです😎

### AI 時代の開発インパクトのリサーチ

GitClear は毎年 AI が開発に与える影響のリサーチペーパーを公開しています。

前述のように Diff Delta はコードのコピーや Churn を検出してスコアリングするという性質上、AI によってこれらがどのように変化したのかにも触れています。

- [Coding on Copilot: 2023 Data Suggests Downward Pressure on Code Quality (incl 2024 projections) - GitClear](https://www.gitclear.com/coding_on_copilot_data_shows_ais_downward_pressure_on_code_quality)
  … 2020〜2023年の約 1.53 億行のコード変更を分析。AI 支援開発の普及に伴い、2 週間以内に書き換えられる Code Churn が 2024 年までに 2021 年比で倍増する見込みであり、コード再利用率の低下と保守性の悪化が示唆された。
- [AI Copilot Code Quality: 2025 Data Suggests 4x Growth in Code Clones - GitClear](https://www.gitclear.com/ai_assistant_code_quality_2025_research)
  … 2020〜2024 年の 2.11 億行のコード変更を分析。AI アシスタントの利用拡大に伴い、クローン（重複）コードが 8.3% から 12.3% に増加した一方で、リファクタリング行は 25% から 10% 未満に低下した。
- [Developer AI Productivity & Analysis Tools: 2026 Research Papers & Resources - GitClear](https://www.gitclear.com/developer_ai_productivity_analysis_tools_research_2026)
  … 2026 年 1 月公開のリサーチで、AI 利用頻度の高い開発者は非利用者と比べて週単位のコミット数が約 5 倍多く、7 つの開発指標のほぼすべてで生産性向上が確認された。ただしツール効果だけでなく、利用する開発者の特性や企業ポリシーといった背景要因の影響も示唆している。
- [How much more productive are AI-powered developers? Large sample productivity data - GitClear](https://www.gitclear.com/research/ai_tool_impact_on_developer_productive_output_from_2022_to_2025)
  … 約 7 万人年規模のデータを分析し、2022〜2025 年にかけて開発者の生産性は中央値で 9% 増加、特に年間 500 コミット以上を行う開発者では 14.1% 増となるなど、AI 支援開発による生産的アウトプットの伸びを定量化した。


これらのリサーチは AI 開発を議論する上での一次情報として、 [Stack Overflow](https://stackoverflow.blog/) や [DevOps.com](https://devops.com/)、 [LeadDev](https://leaddev.com/) などのメディアでも引用されています。[^press]

[^press]: [Press Mentions - GitClear](https://www.gitclear.com/press_mentions)

## GitClear を使う上で気をつけていること

終始 GitClear を絶賛してますが、次のような注意点もあります。

### 英語が前提

日本語の情報はありません。[^jp-info]
UI は英語で操作する必要があり、ヘルプや機能の解説記事も英語です。

[Google 翻訳](https://chromewebstore.google.com/detail/google-translate/aapbdbdomjkkjkaonfhkkikfgjllcleb) などを使ってページを翻訳すればよいかもしれませんが、ヘルプページは iframe による埋め込みで作られているからか、うまく翻訳できないことが多くあります。。

### 複数の指標を使って考える

冒頭に示した[第一原理思考の解説記事](https://www.gitclear.com/help/understand_diff_delta_from_first_principles_stats_on_metric_stability)では「_There's no "silver bullet" developer metric（銀の弾丸となる開発指標はない）_」と述べられています。

Diff Delta という指標は丁寧に調整されていますが、それだけですべてが判断できるわけではありません。

例えば _プルリクエストの作成数_ や _Cycle Time_ といった数値を総合的に見て、全体として開発が良い方向に進んでいるのか、テコ入れが必要なのかを判断する必要があります。

なお、こういった開発指標の考え方について、
GitClear CEO の Bill Harding 氏が熱量のある記事を書いていらっしゃるので、ぜひご参考ください：

https://www.gitclear.com/blog/measuring_durable_change_velocity_in_2026_prompt_to_production_era

https://www.gitclear.com/measuring_code_activity_a_comprehensive_guide_for_the_data_driven

[^jp-info]: GitClear の日本語解説記事は調べた限りこの記事が初のはず…

## あとがき

改めて私は GitClear から依頼を受けてこの記事を書いたわけではありません。

一人の個人として以前から GitClear を推していましたが、AI が開発のあり方を書き換えていく中でも、GitClear は淡々と AI が生み出すコードをリサーチし、「開発がどのように変わってきたのか」「何を指標としそこから何を見出すべきなのか」を第一原理の考え方で考察し、サービスにも反映してきた様子が伺えました。

日本ではほとんど言及されることがないサービスですが、ぜひ一度お試しください。

---

SocialDog はエンジニアを募集しています！ 開発生産性に興味がある方はぜひカジュアル面談にご応募ください！

https://portal.socialdog.jp/recruit
