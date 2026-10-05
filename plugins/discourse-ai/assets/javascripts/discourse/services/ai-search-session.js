import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { searchForTerm, translateResults } from "discourse/lib/search";
import { chooseTab } from "../lib/ai-search-intent";
import { topicIdFromUrl } from "../lib/ai-search-references";
import { withScope } from "../lib/ai-search-scope";

const SEMANTIC_MATCH_RANK = 5;
const BEST_MATCH_COUNT = 2;
// a search this soon after the last one on the same page is still the same hunt
const SEARCH_AGAIN_WINDOW_MS = 3 * 60 * 1000;

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
 *
 * In the menu, every kind of result is fetched at once and offered as a tab,
 * opening on the one the query most likely wants.
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

  @tracked scopeFallback = false;
  @tracked fallbackScopeLabel = null;

  /** The scope the menu is currently in, which the next search starts from. */
  @tracked contextScope = null;

  /**
   * The menu's tab on screen, null until the keyword searches are in and one
   * is chosen.
   *
   * @type {import("../lib/ai-search-intent").SearchTab|null}
   */
  @tracked selectedTab = null;

  /** Each keyword tab's results, null while they load. */
  @tracked topicsResults = null;
  @tracked contextResults = null;

  /** Switches the open search menu to showing topics; set by the menu. */
  showTopicsInMenu = null;

  #subscribed = false;
  #tabChosenByReader = false;
  #lastSearch = null;

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

  get showingRewrittenKeywords() {
    return Boolean(this.keywordQuery) && this.keywordQuery !== this.query;
  }

  /** The results of the keyword tab on screen, if one is. */
  get shownResults() {
    if (this.selectedTab === "topics") {
      return this.topicsResults;
    }
    if (this.selectedTab === "context") {
      return this.contextResults;
    }
    return null;
  }

  get noKeywordMatches() {
    return Boolean(this.shownResults) && !this.shownResults.posts?.length;
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
   * @param {string} [options.trigger] what started the search, for the log
   */
  start(query, surface, scope = null, { trigger = "" } = {}) {
    this.subscribe();

    const searchedAgain = this.#searchedAgain(query);

    this.query = query;
    this.answering = true;
    this.surface = surface;
    this.scope = scope;
    this.scopeFallback = false;
    this.fallbackScopeLabel = null;
    this.keywordQuery = query;
    this.keywordPosts = null;
    this.originalKeywordPosts = null;
    this.rewrittenKeywordQuery = "";
    this.semanticPosts = null;

    this.discoveries.dismissDiscovery();
    this.#ask(query, { trigger });

    if (surface === "menu") {
      this.#searchMenuTabs(query, { searchedAgain });
      this.#lastSearch = { query, at: Date.now() };
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
    this.selectedTab = null;
    this.topicsResults = null;
    this.contextResults = null;
    this.discoveries.dismissDiscovery();
  }

  /** Records the menu's scope, which the next search starts from. */
  updateContextScope(scope) {
    this.contextScope = scope;
  }

  /** Leaving the page ends the hunt, whether or not a result was opened. */
  forgetSearches() {
    this.#lastSearch = null;
  }

  @action
  selectTab(tab) {
    this.#tabChosenByReader = true;
    this.selectedTab = tab;
    this.#showSelectedResults();
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
    if (isCurrent && update.scope_fallback && this.scope) {
      this.scopeFallback = true;
      this.fallbackScopeLabel = this.scope.label;
    }

    this.discoveries.onDiscoveryUpdate(update);
  }

  /**
   * Puts the shown tab's results back if something else replaced them. The
   * menu's own search, started while the reader was still typing, can land
   * after this one and would otherwise swap in results for no topics.
   */
  guardMenuResults() {
    const shown = this.#menuDisplay();
    if (
      this.surface === "menu" &&
      shown &&
      this.search.results !== shown &&
      this.isActiveFor(this.search.activeGlobalSearchTerm)
    ) {
      this.#showSelectedResults();
    }
  }

  // Every tab is searched at once, so switching between them is instant; the
  // one to open on is chosen once the keyword results show what there is.
  async #searchMenuTabs(query, { searchedAgain }) {
    this.#tabChosenByReader = false;
    this.selectedTab = null;
    this.topicsResults = null;
    this.contextResults = null;
    this.search.noResults = false;

    const scopeKey = this.scope?.key;
    const [topics, context] = await Promise.all([
      this.#menuSearch(query),
      scopeKey ? this.#menuSearch(withScope(query, scopeKey)) : null,
    ]);
    if (this.query !== query) {
      return;
    }

    this.topicsResults = topics ?? { posts: [], resultTypes: [] };
    this.contextResults = scopeKey
      ? (context ?? { posts: [], resultTypes: [] })
      : null;

    if (!this.#tabChosenByReader) {
      this.selectedTab = chooseTab(query, {
        topics: this.topicsResults,
        context: this.contextResults,
        scope: scopeKey,
        siteLocale: this.siteSettings.default_locale,
        searchedAgain,
      }).tab;
    }
    this.#showSelectedResults();
  }

  async #menuSearch(term) {
    try {
      const results = await searchForTerm(term);
      // Topics shown through the session are listed by their posts. Left in
      // the topics list, they would have core treat the next keystroke as a
      // full search, logged to recent searches, rather than as typing.
      return results ? { ...results, topics: [] } : null;
    } catch {
      return null;
    }
  }

  // The answer tab still keeps the site-wide results in the menu, so its
  // people and places are there when the reader switches.
  #menuDisplay() {
    return this.shownResults ?? this.topicsResults;
  }

  #showSelectedResults() {
    const shown = this.#menuDisplay();
    if (!shown || this.surface !== "menu") {
      return;
    }
    if (this.search.activeGlobalSearchTerm?.trim() !== this.query) {
      return;
    }

    this.search.noResults = false;
    this.search.results = shown;
  }

  // the rewrite drops filler words, so it is preferred unless it finds less
  async #applyRewrite(update) {
    const query = this.query;
    const rewritten = update.keyword_query || "";
    this.rewrittenKeywordQuery = rewritten;

    if (!rewritten || rewritten === query) {
      return;
    }

    if (this.surface !== "menu") {
      const posts = await keywordSearch(this.#scoped(rewritten));
      if (
        this.query === query &&
        posts.length >= (this.originalKeywordPosts?.length || 0)
      ) {
        this.keywordQuery = rewritten;
        this.keywordPosts = posts;
      }
      return;
    }

    const scopeKey = this.scope?.key;
    const [topics, context] = await Promise.all([
      this.#menuSearch(rewritten),
      scopeKey ? this.#menuSearch(withScope(rewritten, scopeKey)) : null,
    ]);
    if (this.query !== query) {
      return;
    }

    const findsAsMuch = (better, current) =>
      better && (better.posts?.length ?? 0) >= (current?.posts?.length ?? 0);
    if (findsAsMuch(topics, this.topicsResults)) {
      this.topicsResults = topics;
      this.keywordQuery = rewritten;
    }
    if (scopeKey && findsAsMuch(context, this.contextResults)) {
      this.contextResults = context;
    }
    this.#showSelectedResults();
  }

  #ask(query, { trigger }) {
    // a fresh request every time, so the rewrite is always published
    this.discoveries.triggerDiscovery(query, {
      scope: this.scope?.key,
      trigger,
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

  // a second search here, sharing a word with the last, suggests its results
  // did not help
  #searchedAgain(query) {
    const last = this.#lastSearch;
    if (!last || last.query === query) {
      return false;
    }
    if (Date.now() - last.at > SEARCH_AGAIN_WINDOW_MS) {
      return false;
    }

    const words = (text) =>
      new Set(text.toLowerCase().split(/\s+/).filter(Boolean));
    const earlier = words(last.query);
    return [...words(query)].some((word) => earlier.has(word));
  }

  #scoped(query) {
    return withScope(query, this.scope?.key);
  }
}
