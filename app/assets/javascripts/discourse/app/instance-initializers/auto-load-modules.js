import {
  createHelperContext,
  registerHelpers,
} from "discourse-common/lib/helpers";
import Handlebars from "handlebars";
import RawHandlebars from "discourse-common/lib/raw-handlebars";
import { registerRawHelpers } from "discourse-common/lib/raw-handlebars-helpers";
import { setOwner } from "@ember/application";

export function autoLoadModules(owner, registry) {
  Object.keys(requirejs.entries).forEach((entry) => {
    if (/\/helpers\//.test(entry) && !/-test/.test(entry)) {
      requirejs(entry, null, null, true);
    }
    if (/\/widgets\//.test(entry) && !/-test/.test(entry)) {
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
  registerRawHelpers(RawHandlebars, Handlebars);
}

export default {
  after: "inject-objects",
  initialize: (owner) => {
    autoLoadModules(owner, owner.__container__.registry);
  },
};
