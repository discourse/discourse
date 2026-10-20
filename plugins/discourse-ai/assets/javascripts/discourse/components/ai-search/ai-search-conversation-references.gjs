import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { translateResults } from "discourse/lib/search";
import AiSearchReferences, {
  citedTopicsFromCooked,
  citedTopicsFromRaw,
} from "../../lib/ai-search-references.js";
import { semanticSearchable, withScope } from "../../lib/ai-search-scope.js";
import AiSearchReferencesPanel from "./ai-search-references-panel.gjs";

async function keywordSearch(query) {
  try {
    const results = await ajax("/search", { data: { q: query } });
    return (await translateResults(results))?.posts || [];
  } catch {
    return [];
  }
}

async function semanticSearch(query) {
  try {
    const results = await ajax("/discourse-ai/embeddings/semantic-search", {
      data: { q: query, hyde: false },
    });
    return (await translateResults(results))?.posts || [];
  } catch {
    return [];
  }
}

function referenceFromPost(post) {
  return {
    topicId: post.topic_id,
    title: post.topic?.title,
    url: post.url,
    categoryId: post.topic?.category_id,
    excerpt: post.blurb,
  };
}

function textOf(cooked) {
  return new DOMParser().parseFromString(cooked || "", "text/html").body
    .textContent;
}

/**
 * The topics behind a conversation continued from a combined search, reranked
 * as each question is asked and answered. It stands in for the timeline.
 */
export default class AiSearchConversationReferences extends Component {
  @service currentUser;
  @service messageBus;
  @service siteSettings;

  @tracked references = [];

  #ranker = new AiSearchReferences();
  #currentTurn = 0;
  #loaded = false;
  #rankedPostNumber = 0;

  constructor() {
    super(...arguments);
    this.messageBus.subscribe(this.#channel, this.onStream);
    this.#load();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe(this.#channel, this.onStream);
  }

  get #channel() {
    return `discourse-ai/ai-bot/topic/${this.args.topic.id}`;
  }

  get #scope() {
    return this.args.topic.ai_search_scope;
  }

  // A finished reply answers the questions asked since the last one, so they
  // are ranked first, then the topics it cites. A reply that finishes while
  // the conversation loads is ranked with the rest of it.
  @bind
  async onStream(data) {
    if (!this.#loaded || !data?.done || !data.post_number) {
      return;
    }
    if (data.post_number <= this.#rankedPostNumber) {
      return;
    }

    const questions = this.args.topic.postStream.posts.filter(
      (post) =>
        post.post_number > this.#rankedPostNumber &&
        post.post_number < data.post_number &&
        post.user_id === this.currentUser.id
    );
    this.#rankedPostNumber = data.post_number;

    const matches = await Promise.all(
      questions.map((post) => this.#searchQuestion(textOf(post.cooked)))
    );
    matches.forEach((found) => this.#addMatches(++this.#currentTurn, found));

    const cited = data.cooked
      ? citedTopicsFromCooked(data.cooked)
      : citedTopicsFromRaw(data.raw);
    this.#ranker.add(this.#currentTurn, "cited", cited);
    this.references = this.#ranker.rank(this.#currentTurn);
  }

  async #load() {
    let topic;
    try {
      topic = await ajax(`/t/${this.args.topic.id}.json`);
    } catch {
      return;
    }

    this.#ranker.exclude(topic.id);
    const [queryPost, answerPost, ...rest] = await this.#allPosts(topic);
    this.#rankedPostNumber = (rest.at(-1) ?? answerPost)?.post_number ?? 0;

    // Every question is searched at once, then added in turn order as if each
    // had been searched as it was asked.
    const asked = (post) => post.user_id === this.currentUser.id;
    const [firstMatches, ...laterMatches] = await Promise.all([
      this.#searchQuestion(textOf(queryPost?.cooked) || topic.title),
      ...rest.map((post) =>
        asked(post) ? this.#searchQuestion(textOf(post.cooked)) : null
      ),
    ]);

    this.#ranker.add(0, "cited", citedTopicsFromCooked(answerPost?.cooked));
    this.#addMatches(0, firstMatches);
    let turn = 0;
    rest.forEach((post, index) => {
      if (asked(post)) {
        this.#addMatches(++turn, laterMatches[index]);
      } else {
        this.#ranker.add(turn, "cited", citedTopicsFromCooked(post.cooked));
      }
    });
    this.#currentTurn = turn;
    this.#loaded = true;

    this.references = this.#ranker.rank(this.#currentTurn);
  }

  // the topic comes with only its first chunk of posts
  async #allPosts(topic) {
    const loaded = topic.post_stream.posts;
    const loadedIds = new Set(loaded.map((post) => post.id));
    const missing = topic.post_stream.stream.filter((id) => !loadedIds.has(id));
    if (missing.length === 0) {
      return loaded;
    }

    try {
      const more = await ajax(`/t/${topic.id}/posts.json`, {
        data: { post_ids: missing },
      });
      return [...loaded, ...more.post_stream.posts].sort(
        (a, b) => a.post_number - b.post_number
      );
    } catch {
      return loaded;
    }
  }

  async #searchQuestion(question) {
    const scoped = withScope(question, this.#scope);
    const [keyword, semantic] = await Promise.all([
      keywordSearch(scoped),
      this.siteSettings.ai_embeddings_semantic_search_enabled &&
      semanticSearchable(this.#scope)
        ? semanticSearch(scoped)
        : [],
    ]);
    return { keyword, semantic };
  }

  #addMatches(turn, { keyword, semantic }) {
    this.#ranker.add(turn, "keyword", keyword.map(referenceFromPost));
    this.#ranker.add(turn, "semantic", semantic.map(referenceFromPost));
  }

  <template>
    <AiSearchReferencesPanel @references={{this.references}} />
  </template>
}
