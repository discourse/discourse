import { consolePrefix } from "discourse/lib/source-identifier";
import { registerDeprecationHandler } from "discourse-common/lib/deprecated";
import { needsHbrTopicList } from "discourse-common/lib/raw-templates";

export default {
  before: "inject-objects",

  initialize() {
    registerDeprecationHandler((message, opts) => {
      if (opts?.id === "discourse.hbr-topic-list-overrides") {
        needsHbrTopicList(true);
        // eslint-disable-next-line no-console
        console.debug(consolePrefix(), message);
      }
    });
  },
};
