import { h } from "virtual-dom";
import { createWidget } from "discourse/widgets/widget";
import { i18n } from "discourse-i18n";

export default createWidget("topic-post-visited-line", {
  tagName: "div.small-action.topic-post-visited",

  html(attrs) {
    return h(
      `div.topic-post-visited-line.post-${attrs.post_number}}`,
      h("span.topic-post-visited-message", i18n("topics.new_messages_marker"))
    );
  },
});
