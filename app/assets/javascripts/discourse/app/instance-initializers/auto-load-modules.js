import { setOwner } from "@ember/owner";
import Handlebars from "handlebars";
import { createHelperContext, registerHelpers } from "discourse/lib/helpers";
import RawHandlebars from "discourse/lib/raw-handlebars";
import { registerRawHelpers } from "discourse/lib/raw-handlebars-helpers";

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
    siteSettings: owner.lookup("service:site-settings"),
    keyValueStore: owner.lookup("service:key-value-store"),
    capabilities: owner.lookup("service:capabilities"),
    currentUser: owner.lookup("service:current-user"),
    site: owner.lookup("service:site"),
    session: owner.lookup("service:session"),
    topicTrackingState: owner.lookup("service:topic-tracking-state"),
    registry,
  };
  setOwner(context, owner);

  createHelperContext(context);
  registerHelpers(registry);
  registerRawHelpers(RawHandlebars, Handlebars, owner);
}

export default {
  after: "inject-objects",
  initialize: (owner) => {
    autoLoadModules(owner, owner.__container__.registry);
  },
};
