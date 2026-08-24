import { apiInitializer } from "discourse/lib/api";
import { isScopedSearch } from "../lib/search-discoveries-context";

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

  const discobotDiscoveries = api.container.lookup(
    "service:discobot-discoveries"
  );

  api.registerValueTransformer(
    "welcome-banner-search-placeholder",
    ({ value }) =>
      discobotDiscoveries.mode === "ask"
        ? "discourse_ai.discobot_discoveries.mode.ask_placeholder"
        : value
  );

  api.addSearchMenuOnKeyDownCallback((searchMenu, event) => {
    if (!searchMenu) {
      return;
    }

    const query = searchMenu.search.activeGlobalSearchTerm?.trim();

    if (
      isScopedSearch(searchMenu.search) ||
      discobotDiscoveries.mode !== "ask" ||
      discobotDiscoveries.lastQuery === query
    ) {
      return true;
    }

    if (event.key === "Enter" && query?.length > 0) {
      discobotDiscoveries.triggerDiscovery(query);
    }

    return true;
  });

  const search = api.container.lookup("service:search");

  api.addSearchMenuAssistantSelectCallback((args) => {
    if (
      args.updatedTerm === discobotDiscoveries.lastQuery &&
      discobotDiscoveries.discovery
    ) {
      return true;
    }

    if (isScopedSearch(search)) {
      return true;
    }

    if (discobotDiscoveries.mode !== "ask") {
      return true;
    }

    if (args.updatedTerm) {
      discobotDiscoveries.triggerDiscovery(args.updatedTerm);
    }

    return true;
  });
});
