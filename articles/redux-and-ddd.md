---
title: "Redux を DDD で読み解く"
emoji: "⚛️"
type: "tech" # tech: 技術記事 / idea: アイデア
topics: [React,TypeScript,Redux,ReduxToolkit,DDD]
published: true
publication_name: socialdog
---

## 序

一定規模のアプリケーション開発では **ドメイン駆動設計（Domain-Driven Design、以下 DDD）** に代表される設計手法が用いられます。

なぜ DDD をやるのでしょうか。いくつか興味深い先人の言葉を紹介します。



> Bad programmers worry about the code. Good programmers worry about data structures and their relationships.

邦訳：

> バッドプログラマーはコードを心配する。グッドプログラマーはデータ構造とその関連に気を払う。

-- [Re: Licensing and the library version of git [LWN.net] - Linus Torvalds](https://lwn.net/Articles/193245/)

> Data dominates. If you've chosen the right data structures and organized things well, the algorithms will almost always be self-evident. Data structures, not algorithms, are central to programming.

邦訳：

> データが支配する。もし正しいデータ構造を選択し物事をうまく整理できれば、アルゴリズムはほとんどの場合自明になる。プログラミングの中心は、アルゴリズムではなくデータ構造である。

-- [Rob Pike's 5 Rules of Programming](https://users.ece.utexas.edu/~adnan/pike.html)

> Smart data structures and dumb code works a lot better than the other way around.

邦訳：

> スマートなデータ構造とダメなコードは、その逆よりもはるかに良い 

-- [When Is a Rose Not a Rose? - Eric Steven Raymond](http://www.catb.org/~esr/writings/cathedral-bazaar/cathedral-bazaar/ar01s06.html)

「よいシステムをつくる」ことは _よいコードを書くこと_ よりも、**データモデルを適切に定義して扱うこと** なのかもしれません。

### Redux はなぜやるのか

なぜ React などのフレームワークが SPA アプリケーションで使われるとき、Redux といった状態管理ツールと一緒に使われるのでしょうか。

それは **「データモデル」を適切に扱うことが、よいアプリケーションの開発に繋がるからです。**

### Redux と DDD

フロントエンド開発はあまり DDD の文脈で語られることはなく、システム設計の文脈においても「プレゼンテーションを担当」という括りでざっくり「フロントエンド」として扱われがちだということに気づきました。（筆者の主観です）

しかし、昨今のフロントエンド開発は非常に複雑な挙動が可能になっており、「プレゼンテーション」という抽象化の中でも DDD の考え方に通じる設計が行われていると感じています。

この記事では、可能な限りそれらの言語化をしたいと考えています。

またこの記事では筆者が React・Redux、そして ReduxToolkit に馴染んでいるためこれらを使った解説になりますが、他の UI・状態管理フレームワークでも同様の考え方を適用できると考えています。

## この記事はどんな人に向けて書かれたか

- フロントエンド開発をよりよくしたいと考えている人
- DDD を学んだがフロントエンド開発に役立てづらいと感じている人
- DDD をフロントエンド開発に取り入れたい人
- DDD をこれから学んでみたい人

DDD の文脈でよく使われる用語を使っています。そのため DDD の基本知識があると読みやすいと思います。
ですが、ググったり AI に聞いたりすればわかる範囲かと思いますので、フロントエンド開発をしていて DDD に興味がある方にも、学びのひとつのきっかけとして読んでいただければ嬉しいです。

## Redux の責務と混乱

まず Redux を DDD で読み解くための前提として、Redux の責務を次のように整理しておきます。

- フェッチデータをキャッシュする責務
- フロントエンドのドメインモデルを管理する責務

### フェッチデータをキャッシュする責務

Redux ではフェッチデータの取り回しの役割を持つことが多くあります。

- フェッチ済データのキャッシュ
- キャッシュの有効期限管理
- データのリフレッシュ管理
- フェッチステータスの管理（fetching、success、error）

といった役割です。 **リポジトリパターン** による **データアクセスの抽象化** ともいえるかもしれません。

ReduxToolkit は上記のためのツールを [RTK Query](https://redux-toolkit.js.org/rtk-query/overview) というツールセットで提供しています。
RTK Query の Motivation に次のような記述があります。


> the React community has come to realize that "data fetching and caching" is really a different set of concerns than "state management". While you can use a state management library like Redux to cache data, the use cases are different enough that it's worth using tools that are purpose-built for the data fetching use case.

邦訳：

>  React コミュニティは、「データのフェッチとキャッシュ」は「状態管理」と全く異なる懸念事項のセットであることに気づきました。データをキャッシュするために Redux のような状態管理ライブラリを使うことはできますが、ユースケースは十分に異なるので、データフェッチのユースケースのために作られたツールを使うことには価値があります。

[Motivation - RTK Query Overview | Redux Toolkit](https://redux-toolkit.js.org/rtk-query/overview#motivation)

現在 [TanStack Query（旧 React Query）](https://tanstack.com/query/latest) や [SWR](https://swr.vercel.app/) なども広く使われているように、「データフェッチング」の関心事は状態管理の中でも別の関心として捉えるべきだと筆者も考えています。

### フロントエンドのドメインモデルを管理する責務

_フロントエンドのドメインモデル_ とは、 **フロントエンドというコンテキスト境界** 内で管理するドメインモデル ということです。

> **別々のモデルに基づくコードが組み合わされると、ソフトウェアは、バグの温床となり、信頼できなくなり、理解しにくくなる。チームメンバ間のコミュニケーションは混乱し始める。**

_Eric Evans. エリック・エヴァンスのドメイン駆動設計 (Japanese Edition) (p.344). Kindle 版._

ドメインモデルは、コンテキストごと管理されるべきです。

例えば SocialDog の投稿機能では

- 実際に DB へエンティティとして保存するデータ
- フロントエンドで管理する投稿データ

はそれぞれまったく別の形式で表現しています。

![](/images/redux-and-ddd-1.png)
*投稿したコンテンツの一覧。投稿コンテンツはエンティティとして管理される*


![](/images/redux-and-ddd-2.png)
*作成中の投稿コンテンツ。投稿作成に特化したデータモデルで管理される*

あるコンテキストのドメインモデルを別のコンテキストで無理に適用すると、途端にアプリケーション開発がやりづらく、またややこしいものになります。

フロントエンドの主な関心事は「データを適切に見せること」や「ユーザーにデータ操作のためのインターフェースを提供する」ことです。

バックエンドで管理しているドメインモデルが、この関心事に相応しいドメインモデルでなければ、新たに定義し直すことが複雑性の低減に繋がります。

この **「ユーザーにデータ操作のためのインターフェースを提供する」というコンテキスト** 内でドメインを定義・管理・操作するために Redux といった状態管理ライブラリが役立つのです。

## Redux の要素を DDD で読み解く

Redux は次の3つで構成されています。

- store
- reducer
- action

ReduxToolkit では上記を slice という単位でまとめて作成することができます。[^rtk-1]

[^rtk-1]: ReduxToolkit v2.0 から store・reducer・action を個別に作成するのではなく [slice で作成することが推奨されています。](https://redux-toolkit.js.org/usage/migrating-to-modern-redux#reducers-and-actions-with-createslice)

### store - ドメインモデルの管理

データの実態を持つインスタンスになります。基本的にグローバルなシングルトンとしてに管理されますが、**フロントエンドのドメインモデル** はこの store で扱います。

例として、SocialDog の投稿作成機能のドメインモデルを考えてみます。

:::message
実運用コードとは異なります
:::

次のような簡単な要件を定義してみます。

- 投稿をテキストで作成できる
- 作成した投稿は 3 種類の方法で保存できる
  - いますぐ投稿 … すぐに SNS へ投稿する
  - 予約投稿 … 投稿する時間を指定して予約投稿できる
  - 下書き保存 … 下書きとして保存する

これをドメインモデルとして管理するために、次のようなモデルを考えてみます。[^brs]

[^brs]: [Basic Reducer Structure | Redux](https://redux.js.org/usage/structuring-reducers/basic-reducer-structure#basic-state-shape) にあるように、上記のモデルは更に定義を分けて考えることもできます。例えば `contents` や `scheduledAt` は _Domain data_ であり、`submitType` は _App state_ であると言えそうです。


```ts
type SubmitType = 
  | 'POST_NOW'  // いますぐ投稿
  | 'SCHEDULED' // 予約投稿
  | 'DRAFT'     // 下書き保存
;

/** 投稿作成モデル */
type PostState = {
  /** 投稿するコンテンツを管理 */
  contents: string;

  /** 投稿時間を unixtime で管理 */
  scheduledAt: number | null;

  /** 保存方法種別 */
  submitType: SubmitType; 
}
```

### reducer - ドメインロジックの管理

reducer は store を更新する際に用いられる _純粋関数_ です。ここでいう _純粋関数_ とは、[x を入力したら必ず y が返ってくるような副作用をもたない関数](https://redux.js.org/understanding/thinking-in-redux/glossary#reducer) を意味します。

高校数学的に表現すると $y = f(x)$ の $x$ が変更前の store、 $f()$ が reducer, $y$ が変更後の（reducer 関数を通した後の）store です。

ここで重要なのは **「ドメインロジックは reducer に記述される」** ということです。

先程の `PostState` モデルで「下書きを作成中に予約投稿へ変更したくなった」とします。

下書きデータでは「投稿時間」を保持する必要はありませんが、予約投稿では必ず「投稿時間」を設定する必要があります。

このドメイン知識をオブジェクト指向プログラミング（Object-Oriented Programming、以下OOP）で実現すると次のような実装になると思います。

```ts
class PostState {
  // ...
  scheduledAt: number | null;
  submitType: SubmitType;

  // ...

  /** 保存方法種別の設定  */
  setSubmitType(newType: SubmitType): void {
    // 予約投稿の場合に投稿時間を設定する
    if (newType === 'SCHEDULED' && !this.scheduledAt) {
      this.scheduledAt = getDefaultScheduledDatetime();
    }
    this.submitType = newType;
  }
}
```

Redux では reducer で次のように記述できます。 [^1]

[^1]: ReduxToolkit は immer を使っているため副作用を持つ書き方に見えます

```ts
// createSlice 内定義
  reducers: {
    /** 保存方法種別の設定  */
    setSubmitType: (state, action: PayloadAction<SubmitType>) => {
      const newType: SubmitType = action.payload;
      const {scheduledAt} = state;

      if (newType === 'SCHEDULED' && !scheduledAt) {
        // 予約投稿では必ず投稿時間を設定する
        state.scheduledAt = getDefaultScheduledDatetime();
      }

      state.submitType = newType;
    }
  }
```

### action - ドメインイベント

OOP プログラミングにおけるドメインモデルの操作は、インスタンスが公開するドメインメソッドを呼び出すことで行います。

```ts
// 先程の PostState クラスによる概念コード

// インスタンスの作成
const postStatus = new PostStatus({submitType: 'DRAFT'});

// ドメインモデルの操作 → メソッドの呼び出し
postStatus.setSubmitType('SCHEDULED')
```

Redux においては store がもつ dispatch メソッドを通して reducer を適用します。

```ts
const postSlice = createSlice({
  name: 'post'
  reducers: { /* ... */ }
})

// store の作成
const store = configureStore({
  reducer: {post: postSlice.reducer}
  preloadedState: {
    post: {
      submitType: 'DRAFT',
      scheduledAt: undefined,
    }
  }
})

// ドメインモデルの操作 → action を dispatch に渡す
store.dispatch(postSlice.actions.setSubmitType('SCHEDULED'));
```

dispatch には action オブジェクトを渡します。action は `type` と `payload` のプロパティを持つオブジェクトです。

```ts
// postSlice.actions.setSubmitType('SCHEDULED') の返り値
{
  type: 'post/setSubmitType',
  payload: 'SCHEDULED'
}
```

この仕組みはしばしば **[イベントソーシング](https://martinfowler.com/eaaDev/EventSourcing.html)** に似ていると言われます[^es]。その意味では、_store を更新するためのイベント_ が action、_イベント発火処理_ が dispatch の呼び出しといえそうです。

[^es]: [Motivation](https://redux.js.org/understanding/thinking-in-redux/motivation) に _"Following in the steps of [Flux](https://facebookarchive.github.io/flux/), [CQRS](https://martinfowler.com/bliki/CQRS.html), and [Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html), Redux attempts to make state mutations predictable by imposing certain restrictions on how and when updates can happen."_ とあり、イベントソーシングや CQRS の考え方が意識されていることがうかがえます。[Redux and it's relation to CQRS (and other things) · Issue #351 · reduxjs/redux](https://github.com/reduxjs/redux/issues/351) の議論も面白い。

## 補完する概念

store、reducer、action は Redux の基本要素ですが、これ以外にも設計を抽象化する概念が登場します。

### selector - 副作用を持たない store 参照クエリ

selector は store の更新を行いません。

store を引数にとり、任意の値をクライアントが求める形式で返却します。

ドメイン駆動設計の文脈では、画面に対するプレゼンテーションの役割や、サービス層で使われるクエリメソッドの役割を持ちます。

**[CQRS](https://martinfowler.com/bliki/CQRS.html) パターン** でいうと、`dispatch(action)` は（store 更新のための）Command、selector は（store 参照のための） Query に相当します。

Query というと DB アクセスなども含んだリードオンリーな操作をイメージするかもしれませんが、前述のようにデータフェッチは別の関心事として考えているため、selector で API リクエストなどは行いません。あくまで **「フロントで管理している store 参照のための操作」** を指します。

### thunk action

ReduxToolkit では [redux-thunk](https://github.com/reduxjs/redux-thunk) ミドルウェアが同梱されています。

> For Redux specifically, "thunks" are a pattern of writing functions with logic inside that can interact with a Redux store's dispatch and getState methods.

邦訳：

> 特にReduxの場合、"thunks" は Redux ストアの dispatch や getState メソッドとやりとりできるロジックを内部に持つ関数を書くパターンです。

[What is a "thunk"? - Writing Logic with Thunks | Redux](https://redux.js.org/usage/writing-logic-thunks)


単純なドメイン操作ではなく、 _複数のドメインモデルを扱ったりサービス関数を扱ったロジックを含めるとき_ にはこの thunk action にまとめることができ、**アプリケーション層** や **ユースケース層** に相当する役割をもたせることができます。

投稿保存用の thunk action の例を書いてみます。

```ts
/** 投稿の保存 */
export const savePost = (): ThunkAction<void> => {
  return async (dispatch, getState) => {
    // store の参照。もちろん selector も利用できる
    const contents = selectContents(getState());

    // サービス関数の呼び出し
    if (!validateContensService(contents)) {
      return;
    }

    // store から API リクエストに必要なデータを取得
    const apiArgs = selectPostApiArgs(getState());

    try {
      // RTK Query による API 呼び出し
      await dispatch(postApi.endpoints.createPost.initiate(apiArgs))
        .unwrap(); // 例外をキャッチできるよう AsyncThunkAction を unwrap する
    }
    catch {
      return;
    }
  };
};
```

_selector にクエリとしてのロジックを適切に切り出し_ ておくことで、**thunk action 上でもその資産を利用できる** ことがわかります。

サンプルコードでは RTK Query も利用しています。RTK Query は Redux を使っているので当然 Redux action を公開しており、thunk action 内でも利用することができます。

## Redux アーキテクチャのレイヤ

> I call them Mentos and Coke. Both can be great in separation, but together they create a mess. Libraries like React attempt to solve this problem in the view layer by removing both asynchrony and direct DOM manipulation. However, managing the state of your data is left up to you. This is where Redux enters.

邦訳：

> 私はこれをメントスとコーラと呼んでいます。どちらも分離されていれば素晴らしいですが、一緒になるとめちゃめちゃです。React のようなライブラリは、非同期さと直接的な DOM 操作を取り除くことで、ビュー層でこの問題を解決しようとしています。しかし、データの状態を管理するのはあなた次第。ここで Redux の出番です。

[Motivation | Redux](https://redux.js.org/understanding/thinking-in-redux/motivation)

冒頭で述べた「フロントエンドというコンテキストで管理すべきドメインモデル」は、ビュー（React）のレイヤとも切り離して考えることも重要です。

_切り離して考える_ とは

- Redux の知識をビュー（画面）が持つべきではないし、
- ビューの知識を Redux が持つべきではない

ということです。　

### Redux の知識をビューが持つべきではない

次のようなコンポーネントのコードを考えます。

```tsx
function PostEditor(): JSX.Element {

  // 投稿コンテンツ
  const contents = useSelector((store) => {
    // モデルの知識が必要
    return store.post.contents
  });

  // エラーメッセージ
  const errorMessage = useSelector((store) => {
    // バリデーションの知識も必要
    if (!validateContensService(store.post.contents)) {
      return "バリデーションエラー";
    }

    return "";
  });

  return (
    <PostEditorRoot>
      {errorMessage && <ErrorMessage>{errorMessage}</ErrorMessage>}
      <Textarea value={contents} /* ... */ />
    </PostEditorRoot>
  );
};
```

この例では次のようなドメイン知識がビュー（コンポーネント）に漏れ出ています。

- 投稿コンテンツを `store.post.contents` から取得している →  ドメインモデルのデータ構造という知識を知っている
- バリデーション関数を呼び出し、エラーメッセージの生成も行っている →  ドメインモデルとサービス関数を紐づける知識を知っている

ドメイン知識をコンポーネントから取り除く例を見てみます。

ビューは「データのプレゼンテーション」のみを責務とするため、_store データを問い合わせるインターフェース_ は selector として定義し、コンポーネントでこれを使うようにします。[^selector-1]

[^selector-1]: [Container/Presentational Pattern](https://www.patterns.dev/react/presentational-container-pattern) も適用することができますが、割愛しています。


```ts
// selector を slice 内で定義
const postSlice = createSlice({
  name: 'post',
  // ...

  // RTK 2.0 から createSlice 内で selector の定義ができるようなりました
  selectors: {
    selectContents: (state) => state.contents,
    selectErrorMessage: (state) => {
      if (!validateContensService(state.contents)) {
        return "バリデーションエラー";
      }

      return "";
    },
  }
})

export const {
  selectContents,
  selectErrorMessage,
} = postSlice.selectors

```

```tsx
function PostEditor(): JSX.Element {
  // コンポーネントは「どう見せるか」だけを考えたい

  // 投稿コンテンツの取得
  const contents = useSelector(selectContents);

  // エラーメッセージの取得
  const errorMessage = useSelector(selectErrorMessage);

  return (
    <PostEditorRoot>
      {errorMessage && <ErrorMessage>{errorMessage}</ErrorMessage>}
      <Textarea value={contents} /* ... */ />
    </PostEditorRoot>
  );
};
```

[単一責任の原則](https://ja.wikipedia.org/wiki/%E5%8D%98%E4%B8%80%E8%B2%AC%E4%BB%BB%E3%81%AE%E5%8E%9F%E5%89%87) などでも語られるプラクティスに過ぎませんが、

- ドメインモデルやロジックを変更したときに修正しやすくなる
- テストしやすくなる

といった利点があります。

### ビューの知識を Redux が持つべきではない

同様にビュー（コンポーネント）の知識を Redux で持つことは避けます。

先程の thunk action のサンプルコードがもし次のようだったらどうでしょうか。[^rr]

[^rr]: 画面遷移に利用する関数 `navigate` は [React Router を意識したコード](https://reactrouter.com/en/main/hooks/use-navigate)になっています

```ts
/** 投稿の作成 */
export const savePost = (navigate: NavigateFunction): ThunkAction<void> => {
  return async (dispatch, getState) => {
    const contents = selectContents(getState());

    if (!validateContensService(contents)) {
      // エラーダイアログを表示
      dispatch(showErrorDialog('投稿内容が不正です。'));
      return;
    }

    const apiArgs = selectPostApiArgs(getState());

    try {
      await dispatch(postApi.endpoints.createPost.initiate(apiArgs))
        .unwrap(); // エラーキャッチできるように AsyncThunkAction を unwrap する

      // ダイアログを表示
      dispatch(showSuccessDialog('投稿が作成されました。'));

      // 画面遷移
      navigate('/posts');
    }
    catch {
      // エラーダイアログの表示
      dispatch(showErrorDialog('投稿の作成に失敗しました。'));
      return;
    }
  };
};
```

上記コードはドメインモデルの取り扱いとは関係がないビューのためのロジックが含まれています。

- ダイアログの表示
- 画面遷移

これにより、以下の弊害が生まれてしまいます。

- 再利用性の低下
  特定のビューに限定した実装になっています。別のビュー（コンポーネントや画面）で利用するときも、同じロジックが適用されてしまいます。

- 変更コストの増加
  ダイアログ表示や画面遷移のロジックに依存していることで、これらのロジックが変更されたときにもテストを修正する必要があります。

やはりここでも、ビューの知識と Redux の知識を切り離し、疎結合に保つことが重要です。

thunk action を同期的に利用できるようリファクタリングしてみます。

```ts
/** 投稿の作成 */
export const savePost = (): ThunkAction<Promise<{error: string | null}>> => {
  return async (dispatch, getState) => {
    const contents = selectContents(getState());

    if (!validateContensService(contents)) {
      return {error: '投稿内容が不正です。'};
    }

    const apiArgs = selectPostApiArgs(getState());

    try {
      await dispatch(postApi.endpoints.createPost.initiate(apiArgs))
        .unwrap();
    }
    catch {
      return {error: '投稿の作成に失敗しました。'};
    }

    return {error: null}
  };
};
```

thunk action からエラーが返るよう修正しました。これによって、エラー制御は関数の呼び出し側で行えます。また、ダイアログ表示や画面遷移のロジックがなくなりました。

ビュー側で次のような実装ができます。

```ts
/** 投稿保存ボタンクリック時の処理 */
const handleSavePost = async (navigate: NavigateFunction) => {
  const {error} = await dispatch(savePost());

  if (error) {
    dispatch(showErrorDialog(error));
    return;
  }

  dispatch(showSuccessDialog('投稿が作成されました。'));

  // 画面遷移
  navigate('/posts');
}
```

画面遷移のロジックやダイアログ表示のロジックがビューに移動しました。つまり、投稿作成機能を持つ画面やコンポーネントが増えても、画面遷移ロジックやエラー表示の仕様は柔軟に変更できるようになりました。

このように、_ドメインモデルを扱うロジックとビューの責務を分離する_ ことで、保守性の高いコードを記述することができます。

## まとめ

Redux を使うとビューの関心ごととデータモデルの関心ごとを切り離すことができます。

また DDD の考え方は、OOP との実現方法に違いはありながら、React + Redux の考え方でも適用することができます。

---

SocialDog ではフロントエンドエンジニア・バックエンドエンジニアともに募集中です！

https://portal.socialdog.jp/recruit
