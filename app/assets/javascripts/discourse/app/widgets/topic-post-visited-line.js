import I18n from "I18n";
import { createWidget } from "discourse/widgets/widget";
import { h } from "@discourse/virtual-dom";

export default createWidget("topic-post-visited-line", {
  tagName: "div.small-action.topic-post-visited",

  html(attrs) {
    return h(
      `div.topic-post-visited-line.post-${attrs.post_number}}`,
      h("span.topic-post-visited-message", I18n.t("topics.new_messages_marker"))
    );
  },
});
