import { lookup } from "discourse/lib/service";
import { setOwner } from "@ember/owner";
import { createHelperContext, registerHelpers } from "discourse/lib/helpers";
import SiteSettingsService from "discourse/services/site-settings";
import KeyValueStoreService from "discourse/services/key-value-store";
import CapabilitiesService from "discourse/services/capabilities";
import CurrentUserService from "discourse/services/current-user";
import SiteService from "discourse/services/site";
import SessionService from "discourse/services/session";
import TopicTrackingStateService from "discourse/services/topic-tracking-state";

function isThemeOrPluginHelper(path) {
  return (
    path.includes("/helpers/") &&
    (path.startsWith("discourse/theme-") ||
      path.startsWith("discourse/plugins/")) &&
    !path.endsWith("-test")
  );
}

export function autoLoadModules(owner, registry) {
  Object.keys(requirejs.entries).forEach((entry) => {
    if (isThemeOrPluginHelper(entry)) {
      // Once the discourse.register-unbound deprecation is resolved, we can remove this eager loading
      requirejs(entry, null, null, true);
    }
    if (entry.includes("/widgets/") && !entry.endsWith("-test")) {
      requirejs(entry, null, null, true);
    }
  });

  let context = {
    siteSettings: lookup(owner, SiteSettingsService),
    keyValueStore: lookup(owner, KeyValueStoreService),
    capabilities: lookup(owner, CapabilitiesService),
    currentUser: lookup(owner, CurrentUserService),
    site: lookup(owner, SiteService),
    session: lookup(owner, SessionService),
    topicTrackingState: lookup(owner, TopicTrackingStateService),
    registry,
  };
  setOwner(context, owner);

  createHelperContext(context);
  registerHelpers(registry);
}

export default {
  after: "inject-objects",
  initialize: (owner) => {
    autoLoadModules(owner, owner.__container__.registry);
  },
};
