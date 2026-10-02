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
// a search this soon after the last one on the same page is still the same hunt
const SEARCH_AGAIN_WINDOW_MS = 3 * 60 * 1000;
// sooner than this, it is the same search still being typed
const SEARCH_AGAIN_MIN_MS = 2000;

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

  /** @type {import("../lib/ai-search-scope").AiSearchScope|null} */
  @tracked scope = null;
  @tracked answering = false;
  @tracked noKeywordMatches = false;
  @tracked expandedFor = null;

  @tracked scopeFallback = false;
  @tracked fallbackScopeLabel = null;

  /** The scope the menu is currently in, which the next search starts from. */
  @tracked contextScope = null;

  /** A scope the reader took off, which can be put back until they move on. */
  @tracked dismissedScope = null;

  /** Why the last pause left the AI out, for telling when enter overrules it. */
  skipReason = null;

  /** Switches the open search menu to showing topics; set by the menu. */
  showTopicsInMenu = null;

  #subscribed = false;
  #originalMenuSearch = null;
  #menuResults = null;
  #lastSearch = null;
  #termListener = null;

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.#termListener) {
      document.removeEventListener("input", this.#termListener);
    }
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

  get showingRewrittenKeywords() {
    return Boolean(this.keywordQuery) && this.keywordQuery !== this.query;
  }

  /**
   * Whether the reader opened the answer for this search, which then has the
   * menu to itself.
   */
  get expanded() {
    return Boolean(this.query) && this.expandedFor === this.query;
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
   * @param {Object} [options]
   * @param {boolean} [options.answer] whether to ask for an AI answer too, or
   *   only search
   * @param {(results: Object) => boolean} [options.answerAfter] when not
   *   answering, whether to ask once the menu's keyword results are in
   * @param {string} [options.trigger] what started the search, for the log
   * @param {string} [options.reason] why it answers or not, for the log
   * @param {string} [options.answerAfterReason] why, when it answers later
   */
  start(
    query,
    surface,
    scope = null,
    {
      answer = true,
      answerAfter = null,
      trigger = "",
      reason = "",
      answerAfterReason = "",
    } = {}
  ) {
    this.subscribe();

    this.query = query;
    this.answering = answer;
    this.surface = surface;
    this.scope = scope;
    this.scopeFallback = false;
    this.fallbackScopeLabel = null;
    this.keywordQuery = query;
    this.keywordPosts = null;
    this.originalKeywordPosts = null;
    this.rewrittenKeywordQuery = "";
    this.semanticPosts = null;

    this.skipReason = answer ? null : reason;
    this.discoveries.dismissDiscovery();
    if (answer) {
      this.#ask(query, { trigger, reason });
    } else {
      this.semanticPosts = [];
    }

    if (surface === "menu") {
      // what the menu found as the reader typed stays until this search lands,
      // so its users, groups, categories and tags do not blink out
      this.#menuResults = null;
      this.noKeywordMatches = false;
      this.search.noResults = false;
      this.#originalMenuSearch = this.#searchMenu(query, { replace: true });
      this.#lastSearch = { query, at: Date.now() };

      if (!answer && answerAfter) {
        this.#answerAfterResults(query, answerAfter, {
          trigger,
          reason: answerAfterReason,
        });
      }
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
    this.answering = false;
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
      this.start(this.query, "menu", scope, {
        answer: this.answering,
        trigger: "scope",
      });
    }
  }

  /**
   * Whether the reader is searching again after an earlier search on this
   * page, sharing a word with it, which suggests its results did not help.
   */
  searchedAgain(query) {
    const last = this.#lastSearch;
    if (!last) {
      return false;
    }

    // still typing the same search, with a pause along the way
    const lower = query.toLowerCase();
    const earlierLower = last.query.toLowerCase();
    if (lower.startsWith(earlierLower) || earlierLower.startsWith(lower)) {
      return false;
    }

    const age = Date.now() - last.at;
    if (age < SEARCH_AGAIN_MIN_MS || age > SEARCH_AGAIN_WINDOW_MS) {
      return false;
    }

    const words = (text) =>
      new Set(text.toLowerCase().split(/\s+/).filter(Boolean));
    const earlier = words(last.query);
    return [...words(query)].some((word) => earlier.has(word));
  }

  /**
   * Calls back on every change to the header or welcome banner search term,
   * typed or not, so pasting or dictating counts as typing does. Core has
   * already taken the new term by the time the event reaches the document.
   */
  listenForTermChanges(callback) {
    this.#termListener = (event) => {
      if (
        event.target?.classList?.contains("search-term__input") &&
        event.target.closest(
          ".search-input--header, .search-input--welcome-banner"
        )
      ) {
        callback();
      }
    };
    document.addEventListener("input", this.#termListener);
  }

  /** Leaving the page ends the hunt, whether or not a result was opened. */
  forgetSearches() {
    this.#lastSearch = null;
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
    if (isCurrent && update.scope_fallback && !this.scopeFallback) {
      this.#leaveScope();
    }

    this.discoveries.onDiscoveryUpdate(update);
  }

  @action
  toggleExpanded() {
    this.expandedFor = this.expanded ? null : this.query;
  }

  /**
   * Puts this search's results back if something else replaced them. The
   * menu's own search, started while the reader was still typing, can land
   * after this one and would otherwise swap in results for no topics.
   */
  guardMenuResults() {
    if (
      this.surface === "menu" &&
      this.#menuResults &&
      this.search.results !== this.#menuResults &&
      this.isActiveFor(this.search.activeGlobalSearchTerm)
    ) {
      this.#showMenuResults();
    }
  }

  async #applyRewrite(update) {
    const query = this.query;
    this.rewrittenKeywordQuery = update.keyword_query || "";

    if (!this.rewrittenKeywordQuery || this.rewrittenKeywordQuery === query) {
      return;
    }

    if (this.surface === "menu") {
      await this.#swapMenuResults(query);
      return;
    }

    const posts = await keywordSearch(this.#scoped(this.rewrittenKeywordQuery));
    // the rewrite drops filler words, so it is preferred unless it finds less
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
      // Topics shown through the session are listed by their posts. Left in
      // the topics list, they would have core treat the next keystroke as a
      // full search, logged to recent searches, rather than as typing.
      this.#menuResults = { ...results, topics: [] };
      this.#showMenuResults();
    }
    return found;
  }

  // core's empty message speaks of results in general, so the session says
  // itself when no topics matched the keywords
  #showMenuResults() {
    this.search.noResults = false;
    this.search.results = this.#menuResults;
    this.noKeywordMatches = !this.#menuResults.posts?.length;
  }

  #ask(query, { trigger, reason }) {
    // a fresh request every time, so the rewrite is always published
    this.discoveries.triggerDiscovery(query, {
      scope: this.scope?.key,
      trigger,
      triggerReason: reason,
    });

    // Semantic ranks only mark the best matches once there is an answer.
    // Embeddings describe public topics, so they cannot rank within one topic
    // or among messages.
    const semanticInScope = !["topic", "messages"].includes(
      this.scope?.key.split(":")[0]
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
  }

  // A search started without an answer can still earn one once its keyword
  // results show what it is.
  async #answerAfterResults(query, answerAfter, logged) {
    await this.#originalMenuSearch;
    if (
      this.query === query &&
      !this.answering &&
      this.#menuResults &&
      answerAfter(this.#menuResults)
    ) {
      this.answering = true;
      this.skipReason = null;
      this.#ask(query, logged);
    }
  }

  // The answer had to look past the scope, so the search follows it out: the
  // chip comes off, with a way back, and the keyword results widen to match.
  // The answer is not asked for again, as removing the chip would.
  #leaveScope() {
    this.scopeFallback = true;
    if (!this.scope) {
      return;
    }

    this.fallbackScopeLabel = this.scope.label;
    if (this.surface === "menu") {
      this.dismissedScope = this.scope;
      this.scope = null;
      this.#originalMenuSearch = this.#searchMenu(this.keywordQuery, {
        replace: true,
      });
    }
  }

  // keyword results follow the session's scope, which is the chip on screen
  #scoped(query) {
    return withScope(query, this.scope?.key);
  }
}
