import { get } from "@ember/object";
import { getOwner } from "@ember/owner";
import { cancel } from "@ember/runloop";
import { DEFAULT_TYPE_FILTER } from "discourse/components/search-menu";
import { SEARCH_TYPE_DEFAULT } from "discourse/controllers/full-page-search";
import { apiInitializer } from "discourse/lib/api";
import discourseLater from "discourse/lib/later";
import { isValidSearchTerm } from "discourse/lib/search";
import { i18n } from "discourse-i18n";
import { pauseDecision, suggestionInProgress } from "../lib/ai-search-intent";
import { SEARCH_TYPE_ASK_AI } from "../lib/full-page-search-types";
import { isScopedSearch } from "../lib/search-discoveries-context";
import shortcutLabel from "../lib/shortcut-label";

// how long the term has to sit still before combined search runs on its own
const SEARCH_PAUSE_MS = 800;
const MIN_PAUSE_QUERY_LENGTH = 3;

export default apiInitializer((api) => {
  const currentUser = api.getCurrentUser();
  const settings = api.container.lookup("service:site-settings");

  const legacyDiscoveriesAvailable =
    settings.ai_discover_enabled &&
    currentUser?.can_use_ai_discover_agent &&
    currentUser.user_option?.ai_search_discoveries !== false;

  if (settings.ai_discover_enabled && currentUser?.can_use_ai_discover_agent) {
    api.addSaveableUserOption("ai_search_discoveries", { page: "interface" });
  }

  if (!settings.ai_ask_ai_enabled || !currentUser?.can_use_ask_ai) {
    if (legacyDiscoveriesAvailable) {
      initializeLegacyDiscoveries(api);
    }
    return;
  }

  // listed as saveable so the preferences page sends it with the rest
  api.addSaveableUserOption("ai_ask_ai_default", { page: "interface" });

  const search = api.container.lookup("service:search");
  const discobotDiscoveries = api.container.lookup(
    "service:discobot-discoveries"
  );

  const asksByDefault = () =>
    Boolean(get(currentUser, "user_option.ai_ask_ai_default"));

  // enter answers and searches at once, so nothing in the menu picks between them
  const combinedSearch = settings.ai_ask_ai_combined_search_prototype;
  const aiSearchSession = api.container.lookup("service:ai-search-session");
  let pauseTimer = null;
  let pausedQuery = null;

  const cancelPause = () => {
    cancel(pauseTimer);
    pauseTimer = null;
    pausedQuery = null;
  };

  const startCombined = (query, decision = { answer: true }) => {
    cancelPause();
    // the session runs the keyword search as well, in the same scope as the
    // answer, so the menu is switched to showing topics
    aiSearchSession.showTopicsInMenu?.();
    aiSearchSession.start(
      query,
      "menu",
      aiSearchSession.contextScope,
      decision
    );
  };

  // A pause is taken as the reader being done typing. Editing the term clears
  // the answer at once, the way the menu's keyword results clear, so nothing
  // on screen answers a question that is no longer being asked.
  const startAfterPause = () => {
    const query = search.activeGlobalSearchTerm?.trim() ?? "";

    if (!query) {
      cancelPause();
      aiSearchSession.reset();
      return;
    }

    if (query === pausedQuery || aiSearchSession.isActiveFor(query)) {
      return;
    }

    aiSearchSession.reset();
    cancelPause();
    if (
      query.length < MIN_PAUSE_QUERY_LENGTH ||
      !isValidSearchTerm(query, settings) ||
      suggestionInProgress(query)
    ) {
      return;
    }

    pausedQuery = query;
    pauseTimer = discourseLater(() => {
      pauseTimer = null;
      pausedQuery = null;
      // asking straight from the menu got there first
      if (aiSearchSession.isActiveFor(query)) {
        return;
      }
      if (search.activeGlobalSearchTerm?.trim() === query) {
        startCombined(query, {
          ...pauseDecision(query, search.results, {
            siteLocale: settings.default_locale,
            searchedAgain: aiSearchSession.searchedAgain(query),
            scope: aiSearchSession.contextScope?.key,
          }),
          trigger: "pause",
        });
      }
    }, SEARCH_PAUSE_MS);
  };

  if (combinedSearch) {
    aiSearchSession.subscribe();

    // Every change to the term counts, typed or not, so pasting a question or
    // dictating one starts the pause as typing does. Core has already taken
    // the new term by the time the event reaches the document.
    aiSearchSession.listenForTermChanges(startAfterPause);
    // a scope taken off applies to the page it was taken off on
    const contextKey = () => {
      const context = search.searchContext;
      return context ? `${context.type}:${context.id}` : null;
    };
    let lastContextKey = contextKey();

    api.onPageChange(() => {
      aiSearchSession.restoreScope();
      aiSearchSession.forgetSearches();

      // A search belongs to where it was made. Somewhere else it would run
      // again in the new scope the moment the menu opened, so it is cleared.
      const key = contextKey();
      if (key !== lastContextKey) {
        lastContextKey = key;
        cancelPause();
        aiSearchSession.reset();
        search.activeGlobalSearchTerm = "";
        search.noResults = false;
        search.results = {};
      }
    });
  }

  if (!combinedSearch) {
    api.addQuickSearchRandomTip({
      label: shortcutLabel("shift", "enter"),
      get description() {
        return i18n(
          asksByDefault()
            ? "discourse_ai.discobot_discoveries.tip_search"
            : "discourse_ai.discobot_discoveries.tip_ask"
        );
      },
    });
  }

  // Asking is offered on /search the way users and categories are: a type of
  // its own, which owns the results area while it is selected.
  api.addFullPageSearchType(
    "discourse_ai.discobot_discoveries.search_type",
    SEARCH_TYPE_ASK_AI,
    (controller) => {
      controller.setProperties({
        model: { posts: [], topics: [], categories: [], tags: [], users: [] },
        additionalSearchResults: [],
        resultCount: 0,
        searching: false,
        loading: false,
      });

      getOwner(controller)
        .lookup("service:discobot-discoveries")
        .triggerDiscovery(controller.searchTerm?.trim());
    },
    { after: SEARCH_TYPE_DEFAULT }
  );

  // Leading the list when it is what enter runs, so the page opens on the same
  // order the menu offers.
  api.registerValueTransformer("full-page-search-types", ({ value }) => {
    if (!asksByDefault()) {
      return value;
    }

    const ask = value.find(({ id }) => id === SEARCH_TYPE_ASK_AI);
    if (!ask) {
      return value;
    }

    return [ask, ...value.filter((type) => type !== ask)];
  });

  // An answer already on screen is what the reader is looking at, so opening
  // the full page continues it rather than dropping them into an indexed
  // search for the same words.
  api.registerValueTransformer(
    "search-menu-full-search-params",
    ({ value, context }) => {
      if (!offersDiscoveries(context?.location)) {
        return value;
      }

      const query = search.activeGlobalSearchTerm?.trim();
      if (!combinedSearch && query && discobotDiscoveries.lastQuery === query) {
        value.set("search_type", SEARCH_TYPE_ASK_AI);
      }

      return value;
    }
  );

  // the field submits a question rather than a query while asking
  api.registerValueTransformer(
    "full-page-search-button-icon",
    ({ value, context }) =>
      context?.searchType === SEARCH_TYPE_ASK_AI ? "far-discobot" : value
  );

  api.registerValueTransformer(
    "full-page-search-button-label",
    ({ value, context }) =>
      context?.searchType === SEARCH_TYPE_ASK_AI
        ? "discourse_ai.discobot_discoveries.ask_button"
        : value
  );

  // the answer and its sources are the results, so the stock empty state has
  // nothing left to report
  api.registerValueTransformer(
    "full-page-search-no-results-enabled",
    ({ value, context }) =>
      context?.searchType === SEARCH_TYPE_ASK_AI ? false : value
  );

  // Scope used to disqualify the menu entirely, back when it could only be
  // entered from outside. It is one of the inline options now, and picking a
  // wider one releases it, so only the location decides.
  const offersDiscoveries = (location) =>
    ["header", "welcome-banner"].includes(location);

  // Asking is one of the options offered for a typed term rather than a mode,
  // so the placeholder is where the search box says both are available.
  api.registerValueTransformer(
    "search-menu-input-placeholder",
    ({ value, context }) =>
      offersDiscoveries(context?.location)
        ? "discourse_ai.discobot_discoveries.search_placeholder"
        : value
  );

  // the input no longer only searches, so the magnifying glass beside it reads
  // as a claim about what it does; advanced search is still in the field
  api.registerValueTransformer(
    "search-advanced-icon-enabled",
    ({ value, context }) =>
      !combinedSearch && offersDiscoveries(context?.location) ? false : value
  );

  // Once a term has been asked, the indexed results stay behind their option,
  // which reports how many are waiting. They never stack under the answer, not
  // even when it fails to land — the count is the indicator.
  api.registerValueTransformer(
    "search-menu-indexed-results-enabled",
    ({ value, context }) => {
      if (!offersDiscoveries(context?.location)) {
        return value;
      }

      const query = search.activeGlobalSearchTerm?.trim();

      // While typing, the matches core lists are shown in the combined
      // search's own row instead, where they stay once the search runs.
      // Core's list still offers "#" and "@" suggestions.
      // An opened answer has the menu to itself.
      if (combinedSearch) {
        if (aiSearchSession.isActiveFor(query)) {
          return !aiSearchSession.expanded;
        }
        // only core's typing-time list, which has no topics, gives way
        return (
          !query ||
          suggestionInProgress(query) ||
          search.results?.posts?.length > 0
        );
      }

      return !query || discobotDiscoveries.lastQuery !== query;
    }
  );

  // Asked terms live apart from the search log, so the two histories are merged
  // here and each row keeps the icon of the kind of search it repeats.
  api.registerValueTransformer(
    "search-menu-recent-searches",
    ({ value, context }) => {
      if (!offersDiscoveries(context?.location)) {
        return value;
      }

      discobotDiscoveries.loadRecentAsks();

      return [
        ...discobotDiscoveries.recentAsks.map((ask) => ({
          ...ask,
          icon: "far-discobot",
          usage: "recent-ask",
        })),
        ...value,
      ];
    }
  );

  // Clearing the search is a fresh start, so a scope taken off comes back. The
  // answer goes with the term, or the returning scope would re-run it.
  api.registerBehaviorTransformer(
    "search-menu-clear-search",
    ({ context, next }) => {
      if (combinedSearch && offersDiscoveries(context?.location)) {
        cancelPause();
        aiSearchSession.reset();
        aiSearchSession.restoreScope();
      }

      return next();
    }
  );

  // clearing the history clears both lists, since they read as one
  api.registerBehaviorTransformer(
    "search-menu-clear-recent-searches",
    ({ context, next }) => {
      if (offersDiscoveries(context?.location)) {
        discobotDiscoveries.clearRecentAsks();
      }

      return next();
    }
  );

  // each remembered item repeats as the kind of search its icon shows
  api.addSearchMenuAssistantSelectCallback((args) => {
    // a remembered search is set rather than typed, so it starts the combined
    // search itself, decided the way a pause would decide it
    if (
      combinedSearch &&
      ["recent-search", "recent-ask"].includes(args.usage) &&
      args.updatedTerm
    ) {
      args.searchTermChanged(args.updatedTerm);
      startCombined(args.updatedTerm, {
        ...pauseDecision(args.updatedTerm, search.results, {
          siteLocale: settings.default_locale,
          scope: aiSearchSession.contextScope?.key,
        }),
        trigger: "recent",
      });
      return false;
    }

    if (args.usage === "recent-search") {
      discobotDiscoveries.dismissDiscovery();
      return true;
    }

    if (args.usage !== "recent-ask") {
      return true;
    }

    args.searchTermChanged(args.updatedTerm);
    discobotDiscoveries.triggerDiscovery(args.updatedTerm);
    return false;
  });

  api.addSearchMenuOnKeyDownCallback((searchTerm, event) => {
    if (!offersDiscoveries(searchTerm?.args?.location)) {
      return true;
    }

    if (event.key === "Enter") {
      const query = search.activeGlobalSearchTerm?.trim();

      if (combinedSearch) {
        if (!event.shiftKey && query) {
          // an answer already coming for this term is not asked for again,
          // unless it failed; returning false skips the menu's own enter
          // handling, which would otherwise treat a second enter as "open the
          // full page"
          if (
            !aiSearchSession.isActiveFor(query) ||
            !aiSearchSession.answering ||
            aiSearchSession.answerFailed
          ) {
            // asking after a pause left the AI out is the pause guessing
            // wrong, which is worth knowing when tuning it
            const overruled =
              aiSearchSession.isActiveFor(query) && aiSearchSession.skipReason;
            startCombined(query, {
              answer: true,
              trigger: "enter",
              reason: overruled
                ? `after_skip:${aiSearchSession.skipReason}`
                : "",
            });
          }
          return false;
        }
        cancelPause();
        aiSearchSession.reset();
        return true;
      }

      const enterAsks = !search.inTopicContext && asksByDefault();
      if (
        enterAsks &&
        !event.shiftKey &&
        query &&
        (searchTerm.args.typeFilter !== DEFAULT_TYPE_FILTER ||
          discobotDiscoveries.lastQuery === query)
      ) {
        searchTerm.args.fullSearch();
        searchTerm.args.closeSearchMenu();
        return false;
      }

      if (event.shiftKey !== enterAsks && query) {
        // asking honours no scope, so picking it leaves any behind
        searchTerm.args.clearTopicContext();
        searchTerm.args.clearPMInboxContext();
        discobotDiscoveries.triggerDiscovery(query);
        return false;
      }

      discobotDiscoveries.dismissDiscovery();
      return true;
    }

    // An answer belongs to the submission that asked for it, not to the text.
    // Dropping it the moment the box stops matching is what stops it coming
    // back when the same term is typed a second time, since by then the answer
    // it would be matched against is already gone.
    if (
      !combinedSearch &&
      discobotDiscoveries.lastQuery &&
      discobotDiscoveries.lastQuery !== search.activeGlobalSearchTerm?.trim()
    ) {
      discobotDiscoveries.dismissDiscovery();
    }

    return true;
  });

  api.registerValueTransformer(
    "search-menu-input-wrapper-classes",
    ({ value, context }) =>
      offersDiscoveries(context?.location) ? [...value, "--with-ask-ai"] : value
  );

  // the options row always shows which scope is selected
  api.registerValueTransformer(
    "search-menu-search-context-enabled",
    ({ value, context }) =>
      !combinedSearch && offersDiscoveries(context?.location) ? false : value
  );

  // advanced search is offered in the options row instead
  api.registerValueTransformer(
    "search-menu-advanced-button-enabled",
    ({ value, context }) =>
      !combinedSearch && offersDiscoveries(context?.location) ? false : value
  );

  // the menu offers every way to resolve the term as options of its own, or
  // with combined search, enter resolves it every way at once
  api.registerValueTransformer(
    "search-menu-search-shortcuts-enabled",
    ({ value, context }) =>
      offersDiscoveries(context?.location) ? false : value
  );
});

function initializeLegacyDiscoveries(api) {
  const legacyDiscoveries = api.container.lookup(
    "service:legacy-discobot-discoveries"
  );
  const search = api.container.lookup("service:search");

  api.addSearchMenuOnKeyDownCallback((searchMenu, event) => {
    if (!searchMenu) {
      return;
    }

    const query = searchMenu.search.activeGlobalSearchTerm;
    if (
      isScopedSearch(searchMenu.search) ||
      legacyDiscoveries.lastQuery === query
    ) {
      return true;
    }

    if (event.key === "Enter" && query?.length > 0) {
      legacyDiscoveries.triggerDiscovery(query);
    }

    return true;
  });

  api.addSearchMenuAssistantSelectCallback((args) => {
    if (
      args.updatedTerm === legacyDiscoveries.lastQuery &&
      legacyDiscoveries.discovery
    ) {
      return true;
    }

    if (isScopedSearch(search)) {
      return true;
    }

    if (args.updatedTerm) {
      legacyDiscoveries.triggerDiscovery(args.updatedTerm);
    }

    return true;
  });
}
