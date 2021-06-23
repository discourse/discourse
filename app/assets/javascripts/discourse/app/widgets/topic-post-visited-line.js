import I18n from "I18n";
import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";

export default createWidget("topic-post-visited-line", {
  tagName: "div.topic-post-visited-line",

  buildClasses(attrs) {
    return [`post-${attrs.post_number}`];
  },

  html() {
    return h(
      "span.topic-post-visited-message",
      I18n.t("topics.new_messages_marker")
    );
  },
});
