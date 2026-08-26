import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  const currentUser = api.getCurrentUser();
  const settings = api.container.lookup("service:site-settings");

  if (
    !settings.ai_discover_enabled ||
    !currentUser?.can_use_ai_discover_agent
  ) {
    return;
  }

  api.addSaveableUserOption("ai_search_discoveries", { page: "interface" });

  if (currentUser.user_option?.ai_search_discoveries === false) {
    return;
  }

  const search = api.container.lookup("service:search");
  const discobotDiscoveries = api.container.lookup(
    "service:discobot-discoveries"
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

  // a remembered ask repeats as an ask, not as an indexed search
  api.addSearchMenuAssistantSelectCallback((args) => {
    if (args.usage !== "recent-ask") {
      return true;
    }

    args.searchTermChanged(args.updatedTerm);
    discobotDiscoveries.triggerDiscovery(args.updatedTerm);
    return false;
  });

  // enter is the other way to choose the indexed results, and dismisses the
  // answer for the same reason picking "search all topics" does
  api.addSearchMenuOnKeyDownCallback((searchMenu, event) => {
    if (!offersDiscoveries(searchMenu?.args?.location)) {
      return true;
    }

    if (event.key === "Enter") {
      discobotDiscoveries.dismissDiscovery();
      return true;
    }

    // A different term has to be resubmitted anyway, so the option that answered
    // the last one stops applying: the scope is released and the row goes back
    // to offering all three.
    if (search.inTopicContext) {
      searchMenu.clearTopicContext();
    }

    return true;
  });

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
