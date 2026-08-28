import { getOwner } from "@ember/owner";
import { SEARCH_TYPE_DEFAULT } from "discourse/controllers/full-page-search";
import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";
import { SEARCH_TYPE_ASK_AI } from "../lib/full-page-search-types";
import { isScopedSearch } from "../lib/search-discoveries-context";
import shortcutLabel from "../lib/shortcut-label";
import { ASK_MODE, SEARCH_MODE } from "../services/discobot-discoveries";

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

  const search = api.container.lookup("service:search");
  const discobotDiscoveries = api.container.lookup(
    "service:discobot-discoveries"
  );

  // The row of options names this shortcut too, but the tip reaches people who
  // never hover one, alongside the shortcut the menu already teaches.
  api.addQuickSearchRandomTip({
    label: shortcutLabel("shift", "enter"),
    description: i18n("discourse_ai.discobot_discoveries.tip_ask"),
  });

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
      if (query && discobotDiscoveries.lastQuery === query) {
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
      offersDiscoveries(context?.location) ? false : value
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
    if (args.usage === "recent-search") {
      discobotDiscoveries.selectSearchMode(SEARCH_MODE);
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

  // Enter uses the last explicit choice. Shift+Enter remains a direct way to
  // ask, and Ctrl/Cmd+Enter remains advanced search.
  api.addSearchMenuOnKeyDownCallback((searchTerm, event) => {
    if (!offersDiscoveries(searchTerm?.args?.location)) {
      return true;
    }

    if (event.key === "Enter") {
      const query = search.activeGlobalSearchTerm?.trim();

      if (
        query &&
        (event.shiftKey || discobotDiscoveries.searchMode === ASK_MODE)
      ) {
        // asking honours no scope, so picking it leaves any behind
        searchTerm.args.clearTopicContext();
        searchTerm.args.clearPMInboxContext();
        discobotDiscoveries.triggerDiscovery(query);
        return false;
      }

      discobotDiscoveries.selectSearchMode(SEARCH_MODE);
      discobotDiscoveries.dismissDiscovery();
      return true;
    }

    // A different term has to be resubmitted anyway, so the option that answered
    // the last one stops applying: the scope is released and the row goes back
    // to offering all three.
    if (search.inTopicContext) {
      searchTerm.args.clearTopicContext();
    }

    // An answer belongs to the submission that asked for it, not to the text.
    // Dropping it the moment the box stops matching is what stops it coming
    // back when the same term is typed a second time, since by then the answer
    // it would be matched against is already gone.
    if (
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

  // scope is one of the options in the menu, and that row stays put while
  // scoped, so the input never carries a chip for it
  // advanced search is offered in the options row instead
  api.registerValueTransformer(
    "search-menu-advanced-button-enabled",
    ({ value, context }) =>
      offersDiscoveries(context?.location) ? false : value
  );

  api.registerValueTransformer(
    "search-menu-search-context-enabled",
    ({ value, context }) =>
      offersDiscoveries(context?.location) ? false : value
  );

  // the menu offers every way to resolve the term as options of its own
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
