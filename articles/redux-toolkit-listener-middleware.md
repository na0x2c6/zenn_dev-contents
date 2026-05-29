---
title: "Redux Toolkit の Listener Middleware で副作用を扱う"
emoji: "🎧"
type: "tech"
topics: [React, TypeScript, Redux, ReduxToolkit]
published: true
publication_name: socialdog
---

## はじめに

SocialDog ではフロントエンドの状態管理に [Redux Toolkit](https://redux-toolkit.js.org/) を採用しており、その一機能である [**Listener Middleware**](https://redux-toolkit.js.org/api/createListenerMiddleware) を用いています。

Listener Middleware は Redux Toolkit に同梱されている、副作用（side effects）を扱うためのミドルウェアです。`async/await` で記述でき、TypeScript との相性もよく、2 年半にわたって慎重に設計が検討された経緯もあって、軽量ながら強力な機能を備えていると筆者は考えています。

今では Thunk と同様に、Redux で副作用を扱うミドルウェアとして公式に推奨されている機能なのですが、あまり事例が紹介されていないため、本記事で SocialDog での事例を紹介したいと思いました。

本記事では Listener Middleware の概要・基本的な使い方・SocialDog における活用事例を紹介します。Listener Middleware の導入を検討する人にとって、何かしらの参考になれば幸いです。

## この記事で書くこと

- Listener Middleware の概要と、Redux における位置づけ
- Listener Middleware の基本的な使い方
- SocialDog における Listener Middleware の活用事例

## この記事で書かないこと

- Redux / Redux Toolkit 自体の入門的な解説
  - reducer・action・store といった基本要素については簡単に触れますが、Redux 全般の入門記事ではありません
- Redux 自体の利点
  - 本記事の主旨から外れるため踏み込みません
- redux-saga など、Redux Toolkit に同梱されていない副作用ハンドラとの詳細な比較
  - Thunk との比較は本記事の構成上重要なので触れますが、それ以外のミドルウェアとの網羅的な比較は行いません

## 前提：SPA において Flux アーキテクチャが当たり前になった背景

Listener Middleware の考え方を理解しやすくするために、その前提として [**Flux アーキテクチャ**](https://github.com/facebookarchive/flux/tree/main/examples/flux-concepts) の思想を説明します。

Flux アーキテクチャという言葉は聞き慣れないかもしれませんが、Redux のベースにある考え方がこの Flux アーキテクチャであり、Redux はそれを実現する実装のうちの一つです。

なお本記事では、Flux のなかで Redux を採用することの利点には踏み込みません。Redux の目指す思想や設計判断については、Redux メンテナの一人である [Mark Erikson](https://blog.isquaredsoftware.com/about/) 氏による [Idiomatic Redux](https://blog.isquaredsoftware.com/series/idiomatic-redux/) シリーズが詳しいので、興味のある方はそちらをご参照ください。

### なぜ Flux のような状態管理層が必要なのか

[React](https://react.dev/) や [Vue.js](https://vuejs.org/) といったライブラリは、UI を宣言的に書くための道具です。これらは「画面に何を表示するか」を担当します。ただ、「表示する」ための「何」は、どこかから提供する必要があります。

小さなアプリケーションであれば、コンポーネントローカルな状態で事足ります。しかしアプリケーションが大きくなるにつれ、

- 複数のコンポーネントが同じデータを参照したい
- 画面遷移をまたいでも保持したいデータがある
- ある操作が、無関係に見えるあちこちの UI に波及して反映される

といった要求が増えてきます。こうした要求を整理するための **状態管理層** として、Flux は設計パターンの一つとして登場しました。

### Flux の単方向データフロー

Flux のコンセプトはシンプルで、次の 3 行に要約されます。

> Views send actions to the dispatcher. The dispatcher sends actions to every store. Stores send data to the views.
>
> ビューはディスパッチャにアクションを送る。ディスパッチャはすべてのストアにアクションを送る。ストアはビューにデータを送る。
>
> [flux-concepts | facebookarchive/flux](https://github.com/facebookarchive/flux/tree/main/examples/flux-concepts)

構成要素は **Dispatcher / Store / Action / View** の 4 つで、データはこれらの間を _一方向にしか流れない_ のが特徴です。

![Action から Dispatcher、Store、View へとデータが一方向に流れる Flux のデータフロー図](/images/redux-toolkit-listener-middleware__flux-diagram.png)
*引用: [Flux Concepts | facebookarchive/flux](https://github.com/facebookarchive/flux/tree/main/examples/flux-concepts)*

Flux を採用する利点については、2015 年に [Dan Abramov](https://danabra.mov/) 氏（現 Redux のメンテナの一人）が執筆された記事 [The Case for Flux](https://medium.com/swlh/the-case-for-flux-379b7d1982c6) が今でも参考になります。

Flux はビューと状態管理層を明確に切り離した源流とも言える存在で、現在広く使われている Redux はその思想を引き継ぐ実装の一つです。

### 「見せるもの」をコントロールする

機能や UI について考えるとき、私たちはしばしば **「見えるもの」「動くもの」** にばかり気を取られます。しかし見せる UI が成立するためには、その前提として **「見せるべきもの」「動かすべきもの」、つまり実体のオブジェクト** が必要です。

言語学習の例で考えてみます。どれだけ単語や文法を覚えても、 _話したい話題_ がなければ挨拶くらいしか口にできません。同じように、見せるべき _オブジェクト_ （データや状態）がなければ、React をどれだけ学んだところで [Hello, World!](https://ja.wikipedia.org/wiki/Hello_world) と挨拶を表示するくらいしかできません。

React などの「ビュー」が担当するのは、「オブジェクトをどう見せるか」（そして「どう触れてもらうか」）の世界のコーディングです。つまり **ビューはオブジェクトの状態に依存します。** オブジェクトの状態が変われば、ビューは変化します。

そして **「どう見せるか」は、コンテキストによって変わります。**

たとえば同じ職場の同僚でも、一緒に作業をするとき、ランチで雑談するとき、お客さんの前で同席するときとでは、関わり方が変わります。

コンテキストが変われば、同じことを伝えるときでも言葉遣いや表現が変わります。

ここで [オブジェクト指向 UI（OOUI）](https://en.wikipedia.org/wiki/Object-oriented_user_interface) の考え方が参考になります。この考え方では、UI とは「ユーザーにオブジェクトを触れさせるための手段」です。同じオブジェクトでも、どう見せ、どう触れさせるかはコンテキストによって変わります。

画面やコンポーネントなど、あらゆる UI の違いは、突き詰めれば **コンテキストの違い** です。オブジェクトの状態が同じでも、コンテキストが変われば表現方法が変わり、触れ方（操作方法）も変わります。ユーザーとオブジェクトとの関わり方が変わるからです。

ただ、それはオブジェクトが演じる役割が変わるだけで、 **オブジェクト自体の性質には一定の不変性があります。**

この不変性（整合性）を、コンテキストによって姿を変える UI 側で担保しようとすると、画面や機能が増えるほど考慮すべきことが膨らみ、破綻しやすくなります。

そうではなく、 **オブジェクト自身が自己補完的に整合性を担保できるようにしておく** ことで、複雑なアプリケーションでも破綻のない自然な UI を実現できると考えています。

この世界のあらゆるものは、たった 100 個あまりの原子の組み合わせでできています。原子の種類と組み合わせによって私たちの見る・触れる世界が形づくられているように、 **データモデルの振る舞いをコントロールすることは、ユーザーが見て触れる UI の世界を決定すること** につながります。

Flux アーキテクチャの考え方は、 **フロントエンドに専用のモデルを定義し、その状態をコントロール可能にすること** にあります。

### Flux は API レスポンスをキャッシュするためのアーキテクチャではない

少し本旨からはずれますが、誤解されることがあるので述べておきます。

Flux や Redux は、ビューと切り離してフロントエンドの状態を管理できる性質上、 _API レスポンスのキャッシュとしても転用できます_ 。むしろ、状態管理ライブラリの活用例として API キャッシュの用途が広く認知されたため、 _Flux や Redux は API キャッシュのためのアーキテクチャである_ と捉えられることもあります。

ですが、Flux も Redux も「API レスポンスをキャッシュするため」のアーキテクチャではありません。あくまでビューと切り離してフロントエンドのモデルをコントロールするためのものです。

なお、「API のリクエスト状態・キャッシュ管理」という状態管理のパターンはどうしてもボイラープレートになるため、Redux Toolkit にはこの目的に特化した [RTK Query](https://redux-toolkit.js.org/rtk-query/overview) という機能が同梱されています。SocialDog でも OpenAPI スキーマからコードを生成する形で RTK Query を利用しています[^rtk-query-openapi]。

[^rtk-query-openapi]: OpenAPI スキーマから RTK Query のコードを生成する手法については、[2022年Reactを使ってる人には必ず知っていてほしい最強のdata fetchingライブラリであるRTK Queryの優位性とメンテナ](https://zenn.dev/kahirokunn/articles/89ce38fdbf924a)（著者 [@kahirokunn](https://zenn.dev/kahirokunn) さん）で詳しく紹介されています。

## Listener Middleware の紹介

前置きが長くなりましたが、ここからが本題です。

ここまで述べてきた「オブジェクトが自己補完的に整合性を担保する」という考え方を Redux で実現するうえで、Listener Middleware は有力な選択肢になります。

Listener Middleware は、Redux Toolkit に同梱されている、Redux store で **副作用（side effects）を扱うためのミドルウェア** です。

公式ドキュメントは以下にあります。

- [Listeners — Side Effects Approaches | Redux](https://redux.js.org/usage/side-effects-approaches#listeners)
- [createListenerMiddleware | Redux Toolkit](https://redux-toolkit.js.org/api/createListenerMiddleware)

なぜ副作用を扱う「専用の」ミドルウェアが必要なのか、その前提を整理するために、まずは reducer の制約から確認します。

### reducer は純粋関数

Redux における reducer は **純粋関数（pure function）** でなければなりません。

公式ドキュメントは reducer のルールを次のように示しています。

> - They should only calculate the new state value based on the `state` and `action` arguments
> - They are not allowed to modify the existing `state`. Instead, they must make *immutable updates*, by copying the existing `state` and making changes to the copied values.
> - They must not do any asynchronous logic or other "side effects"
>
> - `state` と `action` 引数にのみ基づいて、新しい state の値を計算すること
> - 既存の `state` を変更してはならず、既存の `state` をコピーしてその値に変更を加える *イミュータブルな更新* を行う必要がある
> - 非同期のロジックやその他の「副作用」を行ってはならない
>
> [Rules of Reducers — Redux Fundamentals, Part 3 | Redux](https://redux.js.org/tutorials/fundamentals/part-3-state-actions-reducers#rules-of-reducers)

では「副作用」とは何なのでしょうか。

:::message
「なぜ reducer をこのようなルールに従わせるのか」については本記事の主旨から外れるため踏み込みません。Mark Erikson 氏が執筆された [The Tao of Redux, Part 1: Implementation and Intent](https://blog.isquaredsoftware.com/2017/05/idiomatic-redux-tao-of-redux-part-1/) がとても参考になるので、リンクの紹介に留めます。
:::

### 「副作用」とは

「副作用（side effect）」とは、ドキュメントでは次のように説明されています。

> A "side effect" is any change to state or behavior that can be seen outside of returning a value from a function.
>
> Some common kinds of side effects are things like:
>
> - Logging a value to the console
> - Saving a file
> - Setting an async timer
> - Making an AJAX HTTP request
> - Modifying some state that exists outside of a function, or mutating arguments to a function
> - Generating random numbers or unique random IDs (such as `Math.random()` or `Date.now()`)
>
> 「副作用」とは、関数から値を返す以外の方法で外部から観測できる、状態や振る舞いのあらゆる変化のことである。
>
> 副作用のよくある種類には、たとえば以下のようなものがある。
>
> - コンソールに値をログ出力する
> - ファイルを保存する
> - 非同期タイマーを設定する
> - AJAX で HTTP リクエストを送る
> - 関数の外に存在する状態を変更する、または関数の引数を破壊的に変更する
> - 乱数や一意なランダム ID を生成する（`Math.random()` や `Date.now()` など）
>
> [Side Effects Overview — Side Effects Approaches | Redux](https://redux.js.org/usage/side-effects-approaches#side-effects-overview)

reducer は純粋関数なので、これらを実行することができません。とはいえ実際のアプリケーションでは、API リクエストや localStorage への書き込みなど、副作用なしには成立しない処理がたくさんあります。

Redux では、reducer で扱えないこうした副作用を [ミドルウェアで扱うように設計されています](https://blog.isquaredsoftware.com/presentations/2017-09-might-need-redux-ecosystem/#/18)。Listener Middleware も、その副作用を扱うミドルウェアの一つです。

### Redux で副作用を扱う、他のミドルウェアとの違い

Redux で副作用を扱うミドルウェアは、Listener Middleware だけではありません。

Redux はもともと、 **「ミドルウェアを通じて、好みの構文で副作用の動作をカスタマイズできる」** という思想に基づいて設計されています[^side-effects-customization]。そのため Redux の登場以降、副作用ハンドリングのためのライブラリが数多く生まれてきました。たとえば 2015 年に [redux-saga](https://redux-saga.js.org/) が、2016 年に [redux-observable](https://redux-observable.js.org/) が登場しています。

[^side-effects-customization]: Mark Erikson 氏による [Designing the RTK Listener Middleware - Background: Redux Side Effects Approaches](https://blog.isquaredsoftware.com/2022/03/designing-rtk-listener-middleware/#background-redux-side-effects-approaches) で、 _"Redux was originally designed to use middleware for customizing side effects behavior with your choice of syntax"_ と述べられています。

Redux Toolkit にも [redux-thunk](https://github.com/reduxjs/redux-thunk)（以下、Thunk）が同梱されており、Redux における副作用ハンドラのデフォルトとして推奨されてきました。

Thunk は **命令的に副作用を書く** ためのものです。たとえば「ボタンが押されたら API を呼び、レスポンスを store に保存する」といった処理を、関数として明示的に呼び出す形で記述します。

しかし、Thunk だけでは扱いづらい問題もあります。

**Thunk はキャンセルができない**

途中で処理を打ち切る仕組みが組み込まれていないため、「ユーザーが画面を閉じたら、進行中の検索 API のレスポンス処理を中断したい」のようなケースでは、自前で工夫を加える必要があります。

**Thunk はアクションや状態の変化に自動で反応できない**

Thunk は呼び出されたタイミングで動く関数なので、「あるアクションが dispatch されるたびに副作用を発火させる」といった書き方には向きません。

この制約は、アプリケーションが大きくなるほど保守上の負担として表れてきます。Redux では action : reducer は 1 : N の関係が想定されており[^action-reducer]、状態のツリーは複数の reducer path（slice）に分かれていきます[^reducer-path]。

[^action-reducer]: 前述の [The Tao of Redux, Part 1](https://blog.isquaredsoftware.com/2017/05/idiomatic-redux-tao-of-redux-part-1/) の [Reducer functions should be organized by state slice](https://blog.isquaredsoftware.com/2017/05/idiomatic-redux-tao-of-redux-part-1/#reducer-functions-should-be-organized-by-state-slice) という節で触れられています。

[^reducer-path]: 本記事でいう「reducer path」とは、`combineReducers`（Redux Toolkit では `configureStore` の `reducer` オプション）で組み立てられた状態のツリーのなかで、ある reducer が担当する位置（キー）を指します。たとえば `{ tasks: ..., workspaces: ... }` という状態では、`tasks` と `workspaces` がそれぞれ別の reducer path にあたります。

こうした課題感から、アクションや状態の変化を購読して副作用を発火させるための新しいミドルウェアのアーキテクチャが議論され[^listener-origin]、生まれたのが Listener Middleware です。現在は Listener Middleware も Thunk と同様に、Redux における副作用ロジックの推奨手段とされています[^thunks-and-listeners]。

[^listener-origin]: Listener Middleware が生まれるまでの議論は、[Add an action listener callback middleware · Issue #237 · reduxjs/redux-toolkit](https://github.com/reduxjs/redux-toolkit/issues/237) などで重ねられました。

[^thunks-and-listeners]: Redux 公式の [Style Guide](https://redux.js.org/style-guide/#use-thunks-for-async-logic) では _"Use Thunks and Listeners for Other Async Logic"_ として、命令的な非同期ロジックには Thunk を、状態の変化などに反応する非同期ロジックには Listener Middleware を推奨しています。

## Listener Middleware の基本的な使い方

Listener Middleware を使うときの流れは、次のとおりです。

1. `createListenerMiddleware()` でインスタンスを作成し、store に追加する
2. `startListening()` で副作用を登録する
    - **副作用の発火条件** （いつ発火するか）
    - **副作用の処理** （何をするか）

ここからは、副作用を登録する `startListening()` の使い方を **発火条件** と **処理** に分けて見ていきます。

### 副作用の発火条件

`startListening()` の発火条件は、次の 4 種類のいずれかで指定します。

| 種類 | 指定方法 | 説明 |
|---|---|---|
| `type` | [アクション](https://redux.js.org/understanding/thinking-in-redux/glossary#action) の type 文字列 | 指定した type と完全一致するアクションで発火 |
| `actionCreator` | [action creator](https://redux.js.org/understanding/thinking-in-redux/glossary#action-creator) 関数（Redux Toolkit の [`createAction()`](https://redux-toolkit.js.org/api/createAction) や [`createSlice()`](https://redux-toolkit.js.org/api/createSlice) で作成） | その action creator が生成したアクションで発火 |
| `matcher` | Redux Toolkit の [matcher 関数](https://redux-toolkit.js.org/api/matching-utilities) | `isAnyOf` などで複数アクションをまとめて発火 |
| `predicate` | 真偽値を返す関数 | アクションと現在 / 直前の状態を受け取り、関数で発火条件を記述 |

これら 4 種類を **同じ `startListening` 呼び出し内で複数組み合わせることはできません** 。1 つの listener あたり、1 つの発火条件を選びます。

特に `predicate` は、現在の状態に加えて、アクションが処理される前の状態も引数として受け取れます。そのため、次のようなことができるようになっています。

- 特定のアクションだけでなく、 **任意の状態の変化** に対しても反応して発火できる
- 「ある reducer path の値が前回と異なる」「特定の条件を満たすようになった」といった、 _アクションの種類に依存しない_ 発火条件を書ける

### 副作用の処理（effect）

発火時に実行されるのが `effect` 関数です。`effect` は `action` と `listenerApi` を引数に取ります。

```typescript
listenerMiddleware.startListening({
  actionCreator: todoAdded,
  effect: async (action, listenerApi) => {
    console.log('Todo added: ', action.payload.text);

    const currentState = listenerApi.getState();
    const data = await fetchData();
    listenerApi.dispatch(todoAdded('Buy pet food'));
  },
});
```

`listenerApi` は Thunk の API と似たオブジェクトで、`dispatch` や `getState` を持っています。これに加えていくつかのメソッドが提供されており、それらを使った特徴的な書き方をいくつか紹介します。

#### `async` / `await` で書ける

`effect` は通常の `async` 関数として書けます。

たとえば redux-saga はジェネレータ関数と `yield` 文を組み合わせてアクションに反応する処理を記述する設計を採用していますが、ジェネレータ構文やライブラリ独自のエフェクト API[^saga-yield-syntax] を学習する必要があり、わかりづらいという課題がありました[^saga-complexity]。Listener Middleware では、こうした独自構文を覚える必要なく `async` / `await` で素直に書けます。

[^saga-yield-syntax]: redux-saga のジェネレータ構文とエフェクト API については [Beginner Tutorial | Redux-Saga](https://redux-saga.js.org/docs/introduction/BeginnerTutorial/) をご参照ください。

[^saga-complexity]: Redux 公式の [Side Effects Approaches | Redux](https://redux.js.org/usage/side-effects-approaches#listeners) には _"Sagas: require understanding generator function syntax as well as the saga effects behaviors; add multiple levels of indirection due to needing extra actions dispatched; have poor TypeScript support; and the power and complexity is simply not needed for most Redux use cases."_ という指摘があります。

#### アクションや状態を待てる

`listenerApi.condition()` や `listenerApi.take()` を使うと、 _「特定の条件を満たすアクションや状態の変化が起きるまで待つ」_ という処理を書けます[^saga-take]。

[^saga-take]: redux-saga の [take](https://redux-saga.js.org/docs/api/#takepattern) に相当する機能です。

```typescript
// 条件を満たす状態になるまで待つ（タイムアウトつき）
const finished = await listenerApi.condition(
  (action, currentState) => currentState.value === 3,
  50, // timeout (ms)
);

// アクションと状態の変化を待つ
// タイムアウトすると null、そうでなければ [action, currentState, previousState] が返る
const result = await listenerApi.take(predicate, timeout);
```

#### キャンセルが書ける

`listenerApi.cancelActiveListeners()` を使うと、 _同じ listener の進行中のインスタンスをすべてキャンセルできます_ 。`listenerApi.delay()` と組み合わせれば、より複雑な実行制御も表現できます[^saga-cancel]。

[^saga-cancel]: redux-saga の [takeLatest](https://redux-saga.js.org/docs/api/#takelatestpattern-saga-args) や [debounce](https://redux-saga.js.org/docs/api/#debouncems-pattern-saga-args) に相当する制御を再現できます。

```typescript
listenerMiddleware.startListening({
  actionCreator: increment,
  effect: async (action, listenerApi) => {
    // 進行中の同じ effect をキャンセル
    listenerApi.cancelActiveListeners();
    await listenerApi.delay(15);

    // ここから本処理
  },
});
```

#### 並列処理を起動できる

`listenerApi.fork()` を使うと、effect の中で子タスクを起動して並列に動かせます。戻り値の `task.result` を `await` することで、Promise の `race` のような書き方も表現できます[^saga-fork]。

[^saga-fork]: redux-saga の [fork](https://redux-saga.js.org/docs/api/#forkfn-args) や [race](https://redux-saga.js.org/docs/api/#raceeffects) に相当する機能です。

```typescript
const task = listenerApi.fork(async (forkApi) => {
  await forkApi.delay(5);
  return 42;
});

const result = await task.result;
if (result.status === 'ok') {
  console.log('Child succeeded: ', result.value);
}
```

これらの機能を組み合わせることで、アクションや状態の変化に反応する副作用ロジックを Listener Middleware の機能だけで表現できます。

## SocialDog での Listener Middleware の活用

ここからは、SocialDog で実際に Listener Middleware をどう活用しているかを紹介します。

:::message
基本的な構成は実運用のコードがベースですが、わかりやすさを優先して **架空のチームタスク管理アプリ** として構成し直しています。
:::

題材となる架空アプリの概要は次のとおりです。

- ユーザーは複数の **workspace（チーム）** に所属している
- 各 workspace で **タスク** を作成・編集できる
- workspace ごとに **機能フラグ** （ガントチャート機能の有無など）が設定されている
- メンバーには workspace ごとの **権限** （編集可 / 閲覧のみなど）がある

### ファイル階層と `startListening` の置き場所

`startListening()` をどこで呼ぶかについて、公式ドキュメントはいくつかのパターンを紹介しています[^organizing-listeners]。SocialDog では、slice ごとに `effect.ts` のようなファイルを置き、その中で `startAppListening` を呼ぶ構成を採用しています[^second-pattern]。

[^organizing-listeners]: [Organizing listeners in files | Redux Toolkit](https://redux-toolkit.js.org/api/createListenerMiddleware#organizing-listeners-in-files)

[^second-pattern]: ドキュメントで紹介されているパターンのうち、2 つめの _"have the slice files import the middleware and directly add their listeners"_ に該当します。

ディレクトリのイメージは次のとおりです。

```
src/
├── stores/
│   └── listenerMiddleware.ts   # listenerMiddleware インスタンスと startAppListening を export
└── slices/
    ├── workspaces/
    │   ├── slice.ts
    │   ├── effect.ts           # ← ここで startAppListening を呼ぶ
    │   └── index.ts            # effect.ts を import して setupEffect を呼ぶ
    └── tasks/
        ├── slice.ts
        ├── effect.ts
        └── index.ts
```

`listenerMiddleware.ts` は次のような最小構成です。

```typescript
import { createListenerMiddleware, TypedStartListening } from '@reduxjs/toolkit';

import type { AppDispatch, RootState } from '@/store';

export const listenerMiddleware = createListenerMiddleware();

export const startAppListening =
  listenerMiddleware.startListening as TypedStartListening<RootState, AppDispatch>;
```

各 slice 側の `effect.ts` で `startAppListening` を呼んで listener を登録します。

```typescript
// slices/tasks/effect.ts

import { startAppListening } from '@/stores/listenerMiddleware';

import { tasksApi } from '@/api/tasks';

export const setupEffect = () => {
  startAppListening({
    matcher: tasksApi.endpoints.createTask.matchFulfilled,
    effect: async (action, listenerApi) => {
      // ...
    },
  });
};
```

ここでは 1 つの `effect.ts` にまとめていますが、listener が増えてきたら `effect/` ディレクトリを切って関心ごとにファイルを分割することもあります。slice の規模に応じて構成を調整しています。

そして slice の `index.ts` から `setupEffect()` を呼び出すことで、import 時に listener が登録されます。

```typescript
// slices/tasks/index.ts

import { setupEffect } from './effect';

setupEffect();
```

この構成を採用した理由は次のとおりです。

「[機能的凝集](https://ja.wikipedia.org/wiki/凝集度)」を優先したかった
slice はアクションと reducer を紐づけている場所であり、`startListening` もアクションに対する effect を紐づけているため、同じ場所で扱うほうが自然だと考えました。

import の依存関係を逆転・循環させたくなかった
中央集約で登録する場合、`stores/` 側で各 slice を import する必要があり、依存方向が「基盤 ← 機能」と「機能 ← 基盤」の両方向に伸びてしまいます。

不要になった slice の削除がしやすい
slice ごと `effect.ts` がまとまっているため、その機能が廃止されたら slice ディレクトリを丸ごと消すだけで済みます。

### アクションを購読して UI 通知を生成する

活用パターンの例として、 **RTK Query のレスポンスを購読し、その結果から UI 通知などの派生状態を生成する** ものがあります。

RTK Query は内部的に [`createAsyncThunk`](https://redux-toolkit.js.org/api/createAsyncThunk) のラッパーになっており、リクエストが完了すると `fulfilled` アクションが自動的に dispatch されます。各エンドポイントはこの `fulfilled` アクションにマッチする `matchFulfilled` を公開しており[^rtk-query-matchers]、Listener Middleware はこれを `matcher` 経由で購読できます。

[^rtk-query-matchers]: 各エンドポイントが公開する matcher については [API Slices: Endpoints — Matchers | Redux Toolkit](https://redux-toolkit.js.org/rtk-query/api/created-api/endpoints#matchers) をご参照ください。

たとえば「タスクが作成されたら、通知 slice にトースト用のデータを積む」という処理を考えます。

```typescript
// slices/notifications/effect.ts

import { startAppListening } from '@/stores/listenerMiddleware';

import { tasksApi } from '@/api/tasks';

import { addNotification } from './slice';

export const setupEffect = () => {
  startAppListening({
    matcher: tasksApi.endpoints.createTask.matchFulfilled,
    effect: (action, listenerApi) => {
      const { workspaceId, title } = action.meta.arg.originalArgs;
      const { taskId } = action.payload;

      listenerApi.dispatch(
        addNotification({
          type: 'TaskCreated',
          workspaceId,
          taskId,
          title,
        }),
      );
    },
  });
};
```

ここで、API リクエストボディ（`action.meta.arg.originalArgs`）や API レスポンス（`action.payload`）を参照していることがわかります。

RTK Query が dispatch する `fulfilled` アクションには、これらの値が含まれているということですが、これはつまり RTK Query が扱う Redux の副作用のデータフローと連携して、別の副作用を柔軟に注入できるということを示しています。

Listener Middleware を使って、この `fulfilled` アクションを購読し、後続の副作用を記述しています。

Redux のデータフローに乗せて処理を記述できるので、コンポーネント側で API 呼び出しの引数を保持し直さなくても、副作用ハンドラだけで通知に必要な情報を組み立てられます。

#### UI との接続

直接 Listener Middleware の話ではありませんが、ここで生成した通知の状態を UI とどう接続しているかも、責務分離のわかりやすさのために簡単に紹介します。

UI への接続は、次のように hooks とコンポーネントで役割を分けています。

- hooks は「通知データの selector による取得」と「操作ハンドラの提供」を担当
- コンポーネントは「通知をどう見せるか」だけを担当

たとえば次のような構成です。

```typescript
// hooks/useTaskCreatedNotifications.ts

import { useAppDispatch, useAppSelector } from '@/store/hooks';

import {
  removeNotification,
  selectTaskCreatedNotifications,
} from '@/slices/notifications';

export const useTaskCreatedNotifications = () => {
  const dispatch = useAppDispatch();
  const notifications = useAppSelector(selectTaskCreatedNotifications);

  const dismiss = (notificationId: string) => {
    dispatch(removeNotification({ notificationId }));
  };

  return { notifications, dismiss };
};
```

```tsx
// components/TaskCreatedToasts.tsx

import { useTaskCreatedNotifications } from '@/hooks/useTaskCreatedNotifications';

export const TaskCreatedToasts = () => {
  const { notifications, dismiss } = useTaskCreatedNotifications();

  return (
    <ToastStack>
      {notifications.map((n) => (
        <Toast
          key={n.notificationId}
          onClose={() => dismiss(n.notificationId)}
        >
          タスク「{n.title}」を作成しました
        </Toast>
      ))}
    </ToastStack>
  );
};
```

通知の追加・整合性確保は Listener Middleware に任せ、通知の表示と操作だけを UI 側で扱う、という分業ができます。

### 複数の reducer path にまたがる store の整合性を保つ

Listener Middleware は、 **複数の reducer path にまたがる整合性** を保つ場面でも使えます。

タスク管理アプリで「タスクのアサイン担当者を変更したら、編集権限を持たないメンバーを自動的に除外する」という機能を考えます。

このとき、タスクのアサインに関する状態は `tasks`、メンバーの権限情報は `workspaces` と、それぞれ別の reducer path にあります。Thunk ですべての dispatch 箇所にこの整合性チェックをそれぞれ書くと、新しいアクションが追加されるたびに考慮漏れが起きやすくなります。

Listener Middleware なら、 _「`assigneeIds` への変化」自体_ を購読対象にできます。

```typescript
// slices/tasks/effect.ts

import { startAppListening } from '@/stores/listenerMiddleware';

import { selectWorkspaceMemberPermissions } from '@/slices/workspaces';

import {
  selectTaskAssigneeIds,
  setTaskAssigneeIds,
} from './slice';

export const setupAssigneePermissionListener = () => {
  startAppListening({
    predicate: (_action, currentState, previousState) => {
      // assigneeIds の参照に変化があったときだけ対象にする
      return (
        selectTaskAssigneeIds(currentState) !==
        selectTaskAssigneeIds(previousState)
      );
    },
    effect: async (_action, listenerApi) => {
      const state = listenerApi.getState();
      const assigneeIds = selectTaskAssigneeIds(state);
      const permissions = selectWorkspaceMemberPermissions(state);

      const editableIds = assigneeIds.filter(
        (id) => permissions[id]?.canEdit,
      );

      // 編集権限を持つメンバーだけになるよう補正
      if (editableIds.length !== assigneeIds.length) {
        listenerApi.dispatch(setTaskAssigneeIds(editableIds));
      }
    },
  });
};
```

ポイントは **`predicate` で「`assigneeIds` への変化」だけを発火条件にしている** ことです。これによって、

- どの reducer path / どのアクション経由で `assigneeIds` が変わっても、必ず整合性チェックが走る
- 新しく「メンバーを追加するボタン」を実装しても、整合性チェックのロジックを書き足す必要がない
- ロジックの追加・変更は、この effect ファイル 1 箇所で完結する

といったことが可能になります。store 自身が **「整合性を担保する責務」を自前で持てる** ようになります。Thunk ベースで同じことを実現しようとすると、 _すべての呼び出し側_ で整合性を意識する必要があり、保守コストが膨らんでいきます。

#### UI の整合性を担保する例

UI のルールも、store の整合性として表現できます。架空のタスク管理アプリで、次のような UI ルールを考えてみます。

- タスクの編集モーダルと、タスク詳細を表示するサイドピークビューを **同時に開かない**
- 画面遷移（URL 変更）が起きたら、表示中の通知（トースト）を **すべて閉じる**

どちらも、対応する状態の変化や画面遷移アクションを購読して整合性を取れば、UI 側は _store のままに描画するだけ_ で破綻しません。

たとえば後者の「画面遷移時に通知をクリアする」を Listener Middleware で書くと次のようになります。

```typescript
// 画面遷移時に dispatch するアクション
export const routeChanged = createAction<{ path: string }>('app/routeChanged');

// 画面遷移を起点に通知をクリアする listener
startAppListening({
  actionCreator: routeChanged,
  effect: (_action, listenerApi) => {
    listenerApi.dispatch(clearAllNotifications());
  },
});
```

`routeChanged` を dispatch する側は、[React Router](https://reactrouter.com/) などのルーティングライブラリでパス変化を購読する小さなコンポーネントを 1 つ用意するだけで済みます。

:::details `routeChanged` を dispatch する側のコンポーネント例

```tsx
// components/RouteChangeNotifier.tsx

import { useEffect } from 'react';
import { useLocation } from 'react-router-dom';

import { useAppDispatch } from '@/store/hooks';

import { routeChanged } from '@/slices/app/slice';

/**
 * URL の変化を購読し、 routeChanged アクションを dispatch するだけのコンポーネント。
 * UI は描画しない（renderless）。アプリのルート付近に 1 つだけマウントしておく。
 */
export const RouteChangeNotifier = () => {
  const location = useLocation();
  const dispatch = useAppDispatch();

  useEffect(() => {
    dispatch(routeChanged({ path: location.pathname }));
  }, [location.pathname, dispatch]);

  return null;
};
```

このコンポーネントは描画を持たず、ルーティングと store を橋渡しするだけの役割です。整合性のロジック（「通知をクリアする」「他に閉じておきたい状態がある」など）はすべて Listener Middleware 側に集約されているため、画面側はこの軽量なコンポーネントを置く以外には何もする必要がありません。
:::

この後始末をコンポーネント側に書こうとすると、 _通知を表示し得るすべての画面_ で同じ処理を書くことになります。「URL 変更」というイベントを 1 つのアクションに集約し、Listener Middleware で購読することで、 _どの画面から遷移しても_ 同じ後始末が走ります。

### 状態変化を起点に非同期で検証する

前のセクションでは `predicate` で状態変化に反応しました。さらに effect の中で `listenerApi.condition()` を組み合わせると、 **「状態がある条件になった瞬間に、依存する API データの到着を待ってから検証する」** という非同期の処理も書けます。

タスク編集モーダルを例に取ります。

- ユーザーがモーダルを開くと、`tasks` slice の状態にモーダルの情報（対象タスクとプロジェクト）が入る
- モーダルが開いた状態になったら「ユーザーがそのタスクを編集できる権限を持っているか」を検証したい
- 権限は別の API（`getProjectMembers`）から取得しなければわからない場合がある（キャッシュにないかもしれない）

「モーダルが開いた」という状態変化を `predicate` で捉えれば、モーダルを開く導線がいくつあっても、検証ロジックをこの 1 箇所にまとめられます。

```typescript
// slices/tasks/effect.ts

import { startAppListening } from '@/stores/listenerMiddleware';

import { projectMembersApi } from '@/api/projectMembers';
import { showAlert } from '@/slices/alerts';
import { hideLoadingIcon, showLoadingIcon } from '@/slices/loading';

import { closeTaskEditModal, selectTaskEditModal } from './slice';

export const setupEditPermissionListener = () => {
  startAppListening({
    predicate: (_action, currentState, previousState) => {
      // タスク編集モーダルが「閉じている → 開いた」に変化したときだけ反応する
      return (
        selectTaskEditModal(previousState) === null &&
        selectTaskEditModal(currentState) !== null
      );
    },
    effect: async (_action, listenerApi) => {
      const modal = selectTaskEditModal(listenerApi.getState());
      if (!modal) {
        return;
      }
      const { projectId } = modal;

      // 権限データのキャッシュがなければ取得を開始し、完了を待つ
      const selectQuery = projectMembersApi.endpoints.getProjectMembers.select({
        projectId,
      });

      if (!selectQuery(listenerApi.getState()).isSuccess) {
        // 1000ms 経過したらローディングを表示する子タスクを並列に起動する
        const showLoadingAfterDelay = listenerApi.fork(async (forkApi) => {
          await forkApi.delay(1000);
          listenerApi.dispatch(showLoadingIcon());
        });

        const { unsubscribe } = listenerApi.dispatch(
          projectMembersApi.endpoints.getProjectMembers.initiate({
            projectId,
          }),
        );

        await listenerApi.condition(
          (_action, currentState) => selectQuery(currentState).isSuccess,
        );

        // レスポンスが返ってきたので後始末する
        //  - 1000ms より前に返った場合: 子タスクごとキャンセルされ、ローディングは表示されない
        //  - 1000ms 以降に返った場合: 表示済みのローディングを非表示にする
        showLoadingAfterDelay.cancel();
        listenerApi.dispatch(hideLoadingIcon());

        unsubscribe();
      }

      // 最新の権限で検証
      const state = listenerApi.getState();
      const canEdit = selectQuery(state).data?.find(
        (m) => m.userId === state.session.userId,
      )?.canEdit;

      if (!canEdit) {
        listenerApi.dispatch(showAlert({ message: '編集権限がありません' }));
        listenerApi.dispatch(closeTaskEditModal());
      }
    },
  });
};
```

次のようなことが実現できています。

- `predicate` で状態変化を起点にできる。
  「モーダルが開いた」という状態変化さえ起きれば、どの画面がどうモーダルを開いても同じ検証が走ります。
- `async` / `await` で素直に書ける。
  権限 API の到着を待ってから検証する流れが、ふつうの TypeScript として読めます。
- `listenerApi.condition()` でクエリの完了を待つ。
  キャッシュがあれば即座に進み、なければ取得して完了を待つ、という分岐が一行で書けます。
- `listenerApi.fork()` + `task.cancel()` で「条件付きの遅延表示」が書ける。
  1000ms 経つ前にレスポンスが返ればローディング表示の子タスクごとキャンセルされ、不要な UI 表示を避けられます。

このように、状態の変化に反応するだけでなく、 **依存するデータが揃うのを待ってから処理する** という時間軸まで扱えます。

## まとめ

本記事では Redux Toolkit の **Listener Middleware** について、Redux における位置づけ・基本的な使い方・SocialDog における活用事例を紹介しました。

Listener Middleware は比較的新しい機能で、その設計は 2 年半にわたって議論されてきました（[Designing the RTK Listener Middleware](https://blog.isquaredsoftware.com/2022/03/designing-rtk-listener-middleware/)）。アクションだけでなく状態の変化までを購読でき、 `async` / `await` で、アクションや状態の変化に反応する副作用ロジックを書けます。軽量にもかかわらず非常に強力で、複雑な SPA で必要になる状態管理を可能にする機能です。SocialDog においても、複数の reducer path にまたがる整合性や、非同期検証を含む UI の振る舞いを保つうえで役立っています。

冒頭でも触れたとおり、Listener Middleware は事例をあまり見かけない機能でした。本記事が、Listener Middleware の導入を検討される方の参考になれば幸いです。

---

SocialDog ではフロントエンドエンジニア・バックエンドエンジニアともに募集中です！

https://portal.socialdog.jp/recruit
