import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { searchForTerm, translateResults } from "discourse/lib/search";
import { topicIdFromUrl } from "../lib/ai-search-references";
import { withScope } from "../lib/ai-search-scope";

const SEMANTIC_MATCH_RANK = 5;
const BEST_MATCH_COUNT = 2;

export async function keywordSearch(query) {
  try {
    const results = await ajax("/search", { data: { q: query } });
    return (await translateResults(results))?.posts || [];
  } catch {
    return [];
  }
}

export async function semanticSearch(query) {
  try {
    const results = await ajax("/discourse-ai/embeddings/semantic-search", {
      data: { q: query, hyde: false },
    });
    return (await translateResults(results))?.posts || [];
  } catch {
    return [];
  }
}

/**
 * One combined search: an AI answer, keyword results and semantic results for
 * the same query, shared by the header search menu and the full page.
 */
export default class AiSearchSession extends Service {
  @service discobotDiscoveries;
  @service messageBus;
  @service search;
  @service site;
  @service siteSettings;

  @tracked query = "";
  @tracked surface = null;
  @tracked keywordQuery = "";
  @tracked keywordPosts = null;
  @tracked originalKeywordPosts = null;
  @tracked rewrittenKeywordQuery = "";
  @tracked semanticPosts = null;
  @tracked rewritePending = false;
  @tracked rewriteSettled = false;

  /** @type {import("../lib/ai-search-scope").AiSearchScope|null} */
  @tracked scope = null;
  @tracked scopeFallback = false;

  /** The scope the menu is currently in, which the next search starts from. */
  @tracked contextScope = null;

  /** A scope the reader took off, which can be put back until they move on. */
  @tracked dismissedScope = null;

  #subscribed = false;
  #originalMenuSearch = null;

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.#subscribed) {
      this.messageBus.unsubscribe(
        "/discourse-ai/discoveries",
        this.onDiscovery
      );
    }
  }

  get discoveries() {
    return this.discobotDiscoveries;
  }

  get answerSettled() {
    const discoveries = this.discoveries;
    return (
      !discoveries.loadingDiscoveries &&
      !discoveries.isStreaming &&
      (discoveries.answerable !== null ||
        Boolean(discoveries.errorMessage) ||
        discoveries.discoveryTimedOut)
    );
  }

  get answerFailed() {
    return (
      this.answerSettled &&
      (this.discoveries.answerable === false ||
        Boolean(this.discoveries.errorMessage) ||
        this.discoveries.discoveryTimedOut)
    );
  }

  get relatedTopics() {
    return (this.discoveries.sources || []).map((source) => ({
      ...source,
      categoryModel: this.site.categories?.find(
        (category) => category.id === source.category_id
      ),
    }));
  }

  get citedTopicIds() {
    return new Set(
      this.relatedTopics.map((source) => topicIdFromUrl(source.url))
    );
  }

  get semanticRanks() {
    const ranks = new Map();
    this.semanticPosts?.forEach((post, index) => {
      if (!ranks.has(post.topic_id)) {
        ranks.set(post.topic_id, index + 1);
      }
    });
    return ranks;
  }

  get decorating() {
    return this.answerSettled && Boolean(this.semanticPosts);
  }

  get canFollowUp() {
    return (
      this.answerSettled &&
      !this.answerFailed &&
      Boolean(this.discoveries.activeRequestId)
    );
  }

  /**
   * Whether the keyword query is final, so the label never shows one query and
   * then another. A rewrite is published before any of the answer, so once the
   * answer starts without one, none is coming.
   */
  get rewriteResolved() {
    return (
      !this.rewritePending &&
      (this.rewriteSettled || !this.discoveries.loadingDiscoveries)
    );
  }

  get showingRewrittenKeywords() {
    return Boolean(this.keywordQuery) && this.keywordQuery !== this.query;
  }

  isActiveFor(query) {
    return Boolean(query) && this.query === query.trim();
  }

  /**
   * The strongest of the given results: cited in the answer first, then by
   * semantic rank. Empty until the answer settles.
   */
  bestMatchIds(topicIds) {
    if (!this.decorating) {
      return new Set();
    }

    const rank = (id) => this.semanticRanks.get(id) ?? Infinity;
    const cited = (id) => (this.citedTopicIds.has(id) ? 0 : 1);

    return new Set(
      [...new Set(topicIds)]
        .filter((id) => cited(id) === 0 || rank(id) <= SEMANTIC_MATCH_RANK)
        .sort((a, b) => cited(a) - cited(b) || rank(a) - rank(b))
        .slice(0, BEST_MATCH_COUNT)
    );
  }

  /**
   * @param {string} query
   * @param {"menu"|"page"} surface where the keyword results are shown
   * @param {import("../lib/ai-search-scope").AiSearchScope|null} [scope]
   */
  start(query, surface, scope = null) {
    this.subscribe();

    this.query = query;
    this.surface = surface;
    this.scope = scope;
    this.scopeFallback = false;
    this.keywordQuery = query;
    this.keywordPosts = null;
    this.originalKeywordPosts = null;
    this.rewrittenKeywordQuery = "";
    this.semanticPosts = null;
    this.rewritePending = false;
    this.rewriteSettled = false;

    // a fresh request every time, so the rewrite is always published
    this.discoveries.dismissDiscovery();
    this.discoveries.triggerDiscovery(query, { scope: scope?.key });

    // embeddings describe public topics, so they cannot rank within one topic
    // or among messages
    const semanticInScope = !["topic", "messages"].includes(
      scope?.key.split(":")[0]
    );
    if (
      this.siteSettings.ai_embeddings_semantic_search_enabled &&
      semanticInScope
    ) {
      semanticSearch(this.#scoped(query)).then((posts) => {
        if (this.query === query) {
          this.semanticPosts = posts;
        }
      });
    } else {
      this.semanticPosts = [];
    }

    if (surface === "menu") {
      this.search.noResults = false;
      this.search.results = {};
      this.#originalMenuSearch = this.#searchMenu(query, { replace: true });
    } else {
      keywordSearch(this.#scoped(query)).then((posts) => {
        if (this.query !== query) {
          return;
        }
        this.originalKeywordPosts = posts;
        if (this.keywordQuery === query) {
          this.keywordPosts = posts;
        }
      });
    }
  }

  /**
   * Listens for answers ahead of the first question, so an update published
   * soon after asking is not missed while the subscription is still reaching
   * the server.
   */
  subscribe() {
    if (!this.#subscribed) {
      this.messageBus.subscribe("/discourse-ai/discoveries", this.onDiscovery);
      this.#subscribed = true;
    }
  }

  reset() {
    this.query = "";
    this.scope = null;
    this.discoveries.dismissDiscovery();
  }

  /**
   * Follows the menu's scope. A search already on screen is run again in the
   * new scope, since the chip is the reader's way of widening or narrowing it.
   */
  updateContextScope(scope) {
    this.contextScope = scope;

    if (
      this.surface === "menu" &&
      this.query &&
      scope?.key !== this.scope?.key
    ) {
      this.start(this.query, "menu", scope);
    }
  }

  @action
  dismissScope(scope) {
    this.dismissedScope = scope;
  }

  @action
  restoreScope() {
    this.dismissedScope = null;
  }

  useOriginalKeywords() {
    this.keywordQuery = this.query;
    if (this.surface === "page") {
      this.keywordPosts = this.originalKeywordPosts;
    }
  }

  async startConversation(question) {
    const result = await ajax("/discourse-ai/discoveries/continue-convo", {
      type: "POST",
      data: { request_id: this.discoveries.activeRequestId, question },
    });
    return result.topic_id;
  }

  @bind
  onDiscovery(update) {
    if (!this.query || update.query !== this.query) {
      return;
    }

    const isCurrent = update.request_id === this.discoveries.activeRequestId;
    if (isCurrent && update.phase === "rewritten") {
      this.#applyRewrite(update);
    }
    if (isCurrent && update.scope_fallback) {
      this.scopeFallback = true;
    }

    this.discoveries.onDiscoveryUpdate(update);
  }

  async #applyRewrite(update) {
    const query = this.query;
    this.rewritePending = true;
    try {
      await this.#chooseKeywordQuery(query, update.keyword_query || "");
    } finally {
      if (this.query === query) {
        this.rewritePending = false;
        this.rewriteSettled = true;
      }
    }
  }

  async #chooseKeywordQuery(query, rewrittenKeywordQuery) {
    this.rewrittenKeywordQuery = rewrittenKeywordQuery;

    if (!this.rewrittenKeywordQuery || this.rewrittenKeywordQuery === query) {
      return;
    }

    if (this.surface === "menu") {
      await this.#swapMenuResults(query);
      return;
    }

    const posts = await keywordSearch(this.#scoped(this.rewrittenKeywordQuery));
    // the rewrite drops filler words, so it is the clearer label for the same
    // matches and is kept unless it finds less
    if (
      this.query === query &&
      posts.length >= (this.originalKeywordPosts?.length || 0)
    ) {
      this.keywordQuery = this.rewrittenKeywordQuery;
      this.keywordPosts = posts;
    }
  }

  async #swapMenuResults(query) {
    const originalCount = (await this.#originalMenuSearch) ?? 0;
    const count = await this.#searchMenu(this.rewrittenKeywordQuery, {
      replace: (found) => this.query === query && found >= originalCount,
    });

    if (this.query === query && count !== null && count >= originalCount) {
      this.keywordQuery = this.rewrittenKeywordQuery;
    }
  }

  /**
   * Runs the menu's keyword search in the session's scope, which the menu's own
   * search only applies for topics and messages.
   *
   * @returns {Promise<number|null>} how many posts it found, or null on failure
   */
  async #searchMenu(keywordQuery, { replace }) {
    const query = this.query;
    let results;
    try {
      results = await searchForTerm(this.#scoped(keywordQuery));
    } catch {
      return null;
    }

    const found = results?.posts?.length ?? 0;
    const stillCurrent =
      this.query === query &&
      this.search.activeGlobalSearchTerm?.trim() === query;
    const shouldReplace =
      typeof replace === "function" ? replace(found) : replace;

    if (results && stillCurrent && shouldReplace) {
      this.search.noResults = results.resultTypes.length === 0;
      this.search.results = results;
    }
    return found;
  }

  // Keyword results stay in the scope even when the answer had to leave it,
  // so they always match the chip the reader can see.
  #scoped(query) {
    return withScope(query, this.scope?.key);
  }
}
