import { apiInitializer } from "discourse/lib/api";
import { isScopedSearch } from "../lib/search-discoveries-context";

export default apiInitializer((api) => {
  const currentUser = api.getCurrentUser();
  const settings = api.container.lookup("service:site-settings");

  if (
    !settings.ai_discover_enabled ||
    (!currentUser?.can_use_ai_discover_agent &&
      !currentUser?.can_use_ai_discover_agent)
  ) {
    return;
  }

  api.addSaveableUserOption("ai_search_discoveries", { page: "interface" });

  const discobotDiscoveries = api.container.lookup(
    "service:discobot-discoveries"
  );

  api.addSearchMenuOnKeyDownCallback((searchMenu, event) => {
    if (!searchMenu) {
      return;
    }

    const query = searchMenu.search.activeGlobalSearchTerm;

    if (
      isScopedSearch(searchMenu.search) ||
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

    if (args.updatedTerm) {
      discobotDiscoveries.triggerDiscovery(args.updatedTerm);
    }

    return true;
  });
});
