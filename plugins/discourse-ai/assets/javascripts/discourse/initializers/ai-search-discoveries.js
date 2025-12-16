import { apiInitializer } from "discourse/lib/api";

const FIELD_NAME = "ai_search_discoveries";

export default apiInitializer((api) => {
  const currentUser = api.getCurrentUser();
  const settings = api.container.lookup("service:site-settings");

  if (
    !settings.ai_discover_enabled ||
    !currentUser?.can_use_ai_discover_persona
  ) {
    return;
  }

  api.addSaveableUserOptionField(FIELD_NAME);

  api.registerValueTransformer(
    "preferences-save-attributes",
    ({ value: attrs, context }) => {
      if (context.page === "interface") {
        attrs.push(FIELD_NAME);
      }
      return attrs;
    }
  );

  const discobotDiscoveries = api.container.lookup(
    "service:discobot-discoveries"
  );

  api.addSearchMenuOnKeyDownCallback((searchMenu, event) => {
    if (!searchMenu) {
      return;
    }

    const query = searchMenu.search.activeGlobalSearchTerm;

    // We only trigger discover when searching on all topics.
    if (
      searchMenu.search?.searchContext?.type ||
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

    // We only trigger discover when searching on all topics.
    if (search?.searchContext?.type) {
      return true;
    }

    if (args.updatedTerm) {
      discobotDiscoveries.triggerDiscovery(args.updatedTerm);
    }

    return true;
  });
});
