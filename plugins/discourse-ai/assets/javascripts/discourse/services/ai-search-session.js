import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";
import { searchForTerm } from "discourse/lib/search";
import { followUpAvailable } from "../lib/ai-follow-up.js";
import { chooseTab, readsAsQuestion } from "../lib/ai-search-intent.js";
import { withScope } from "../lib/ai-search-scope.js";

// a search this soon after the last one on the same page is still the same hunt
const SEARCH_AGAIN_WINDOW_MS = 3 * 60 * 1000;
// how long the tabs wait on the reply's judgements before judging the query alone
const INTENT_WAIT_MS = 1000;

function preservesMatches(results, other) {
  if (!results) {
    return false;
  }

  const postIds = new Set((results.posts ?? []).map((post) => post.id));
  return (other?.posts ?? []).every((post) => postIds.has(post.id));
}

/**
 * One combined search in the header search menu: the AI answer and keyword
 * results for the same query, fetched at once and offered as tabs, opening on
 * the one the query most likely wants.
 */
export default class AiSearchSession extends Service {
  @service appEvents;
  @service currentUser;
  @service discobotDiscoveries;
  @service messageBus;
  @service search;
  @service site;
  @service siteSettings;

  @tracked query = "";

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
  // the menu search's tab choices, logged on its ask to judge how well the
  // opening tab was chosen
  #tabLog = null;

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.#subscribed) {
      this.messageBus.unsubscribe(
        "/discourse-ai/discoveries",
        this.onDiscovery
      );
      this.appEvents.off("discourse-ai:answer-failed", this.onAnswerFailed);
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

  /** Whether the answer broke down, rather than finding nothing to say. */
  get answerErrored() {
    return (
      this.answerSettled &&
      (Boolean(this.discoveries.errorMessage) ||
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

  get canFollowUp() {
    return (
      followUpAvailable(this.siteSettings, this.currentUser) &&
      this.answerSettled &&
      !this.answerFailed &&
      Boolean(this.discoveries.activeRequestId)
    );
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
   * @param {string} query
   * @param {import("../lib/ai-search-scope").AiSearchScope|null} [scope]
   * @param {Object} [options]
   * @param {string} [options.trigger] what started the search, for the log
   */
  start(query, scope = null, { trigger = "" } = {}) {
    this.subscribe();

    const searchedAgain = this.#searchedAgain(query);

    this.query = query;
    this.answering = true;
    this.scope = scope;
    this.scopeFallback = false;
    this.fallbackScopeLabel = null;

    this.discoveries.dismissDiscovery();
    const asked = this.#ask(query, { trigger });

    this.#searchMenuTabs(query, { searchedAgain, asked });
    this.#lastSearch = { query, at: Date.now() };
  }

  /**
   * Listens for answers ahead of the first question, so an update published
   * soon after asking is not missed while the subscription is still reaching
   * the server.
   */
  subscribe() {
    if (!this.#subscribed) {
      this.messageBus.subscribe("/discourse-ai/discoveries", this.onDiscovery);
      this.appEvents.on("discourse-ai:answer-failed", this.onAnswerFailed);
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
    const log = this.#tabLog;
    if (log && !log.switched && tab !== this.selectedTab) {
      log.switched = true;
      this.#recordTabs(log, {
        tab_switched_to: tab,
        tab_switched_after_ms: Date.now() - log.since,
      });
    }

    this.#tabChosenByReader = true;
    this.selectedTab = tab;
    this.#showSelectedResults();
  }

  async startConversation(question) {
    const result = await ajax("/discourse-ai/discoveries/continue-convo", {
      type: "POST",
      data: { request_id: this.discoveries.activeRequestId, question },
    });
    return result.topic_id;
  }

  @bind
  onAnswerFailed() {
    this.#leaveFailedAnswer();
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
      shown &&
      this.search.results !== shown &&
      this.isActiveFor(this.search.activeGlobalSearchTerm)
    ) {
      this.#showSelectedResults();
    }
  }

  // Every tab is searched at once, so switching between them is instant; the
  // one to open on is chosen once the keyword results show what there is.
  async #searchMenuTabs(query, { searchedAgain, asked }) {
    const log = { asked, since: Date.now(), switched: false };
    this.#tabLog = log;
    this.#tabChosenByReader = false;
    this.selectedTab = null;
    this.topicsResults = null;
    this.contextResults = null;
    this.search.noResults = false;

    const scopeKey = this.scope?.key;
    const replied = this.#waitForReply(asked);
    const [topics, context] = await Promise.all([
      this.#menuSearch(query),
      scopeKey ? this.#menuSearch(withScope(query, scopeKey)) : null,
    ]);
    if (this.query !== query) {
      return;
    }

    // A rewrite can land first, but must retain the original matches.
    const empty = { posts: [], resultTypes: [] };
    if (!preservesMatches(this.topicsResults, topics)) {
      this.topicsResults = topics ?? empty;
    }
    if (scopeKey && !preservesMatches(this.contextResults, context)) {
      this.contextResults = context ?? empty;
    }

    const reply = await replied;
    if (this.query !== query) {
      return;
    }

    if (!this.#tabChosenByReader) {
      const { tab, reason } = chooseTab(query, {
        topics: this.topicsResults,
        context: this.contextResults,
        scope: scopeKey,
        siteLocale: this.siteSettings.default_locale,
        searchedAgain,
        intent: reply?.intent,
        prefersResults: reply?.prefers_results,
      });
      this.selectedTab = tab;
      log.since = Date.now();
      this.#recordTabs(log, { tab_opened: tab, tab_opened_reason: reason });
      if (this.answerFailed) {
        this.#leaveFailedAnswer();
      }
    }
    this.#showSelectedResults();
  }

  // a failed answer is a dead end, so the reader is moved to results that exist
  #leaveFailedAnswer() {
    if (this.selectedTab !== "ask" || this.#tabChosenByReader) {
      return;
    }

    if (this.contextResults?.posts?.length) {
      this.selectedTab = "context";
    } else if (this.topicsResults?.posts?.length) {
      this.selectedTab = "topics";
    } else {
      return;
    }
    this.#showSelectedResults();
  }

  async #recordTabs(log, data) {
    const askLogId = (await log.asked)?.ask_log_id;
    if (!askLogId) {
      return;
    }

    try {
      await ajax("/discourse-ai/discoveries/tabs", {
        type: "PUT",
        data: { ask_log_id: askLogId, ...data },
      });
    } catch {
      // only the measurement is lost
    }
  }

  async #waitForReply(asked) {
    const waited = new Promise((resolve) =>
      setTimeout(resolve, INTENT_WAIT_MS, null)
    );
    return await Promise.race([asked, waited]);
  }

  async #menuSearch(term) {
    try {
      // a tab's "more" opens the full page on the very terms it searched
      const results = await searchForTerm(term, {
        fullSearchUrl: () => getURL(`/search?q=${encodeURIComponent(term)}`),
      });
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
    if (!shown) {
      return;
    }
    if (this.search.activeGlobalSearchTerm?.trim() !== this.query) {
      return;
    }

    this.search.noResults = false;
    this.search.results = shown;
  }

  // More results do not guarantee that the original matches survived a rewrite.
  async #applyRewrite(update) {
    const query = this.query;
    const rewritten = update.keyword_query || "";
    if (!rewritten || rewritten === query) {
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

    if (preservesMatches(topics, this.topicsResults)) {
      this.topicsResults = topics;
    }
    if (scopeKey && preservesMatches(context, this.contextResults)) {
      this.contextResults = context;
    }
    this.#showSelectedResults();
  }

  #ask(query, { trigger }) {
    // a fresh request every time, so the rewrite is always published
    return this.discoveries.triggerDiscovery(query, {
      scope: this.scope?.key,
      trigger,
      intentHeuristic: readsAsQuestion(query) ? "answer" : "lookup",
      classifyIntent:
        !!this.siteSettings.ai_ask_ai_search_intent_decision_model,
    });
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
}
