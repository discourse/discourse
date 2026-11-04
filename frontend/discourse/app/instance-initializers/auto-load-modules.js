import { setOwner } from "@ember/owner";
import { createHelperContext, registerHelpers } from "discourse/lib/helpers";

export function autoLoadModules(owner, registry) {
  Object.keys(requirejs.entries).forEach((entry) => {
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
}

export default {
  after: "inject-objects",
  initialize: (owner) => {
    autoLoadModules(owner, owner.__container__.registry);
  },
};
