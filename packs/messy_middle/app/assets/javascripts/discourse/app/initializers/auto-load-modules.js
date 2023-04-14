import {
  createHelperContext,
  registerHelpers,
} from "discourse-common/lib/helpers";
import Handlebars from "handlebars";
import RawHandlebars from "discourse-common/lib/raw-handlebars";
import { registerRawHelpers } from "discourse-common/lib/raw-handlebars-helpers";
import { setOwner } from "@ember/application";

export function autoLoadModules(container, registry) {
  Object.keys(requirejs.entries).forEach((entry) => {
    if (/\/helpers\//.test(entry) && !/-test/.test(entry)) {
      requirejs(entry, null, null, true);
    }
    if (/\/widgets\//.test(entry) && !/-test/.test(entry)) {
      requirejs(entry, null, null, true);
    }
  });

  let context = {
    siteSettings: container.lookup("service:site-settings"),
    keyValueStore: container.lookup("service:key-value-store"),
    capabilities: container.lookup("service:capabilities"),
    currentUser: container.lookup("service:current-user"),
    site: container.lookup("service:site"),
    session: container.lookup("service:session"),
    topicTrackingState: container.lookup("service:topic-tracking-state"),
    registry,
  };
  setOwner(context, container);

  createHelperContext(context);
  registerHelpers(registry);
  registerRawHelpers(RawHandlebars, Handlebars);
}

export default {
  name: "auto-load-modules",
  after: "inject-objects",
  initialize: (container) => autoLoadModules(container, container.registry),
};
