import { h } from "virtual-dom";
import { createWidget } from "discourse/widgets/widget";
import I18n from "discourse-i18n";

export default createWidget("topic-post-visited-line", {
  tagName: "div.small-action.topic-post-visited",

  html(attrs) {
    return h(
      `div.topic-post-visited-line.post-${attrs.post_number}}`,
      h("span.topic-post-visited-message", I18n.t("topics.new_messages_marker"))
    );
  },
});
