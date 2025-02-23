import { registerDeprecationHandler } from "discourse/lib/deprecated";
import { needsHbrTopicList } from "discourse/lib/raw-templates";

export default {
  before: "inject-objects",

  initialize() {
    registerDeprecationHandler((message, opts) => {
      if (opts?.id === "discourse.hbr-topic-list-overrides") {
        needsHbrTopicList(true);
      }
    });
  },
};
