import { h } from "virtual-dom";
import TopicStatusIcons from "discourse/helpers/topic-status-icons";
import { iconNode } from "discourse/lib/icon-library";
import { escapeExpression } from "discourse/lib/utilities";
import { createWidget } from "discourse/widgets/widget";
import { i18n } from "discourse-i18n";

export default createWidget("topic-status", {
  tagName: "span.topic-statuses",

  html(attrs) {
    const topic = attrs.topic;
    const canAct = this.currentUser && !attrs.disableActions;

    const result = [];

    TopicStatusIcons.render(topic, function (name, key) {
      const iconArgs = { class: key === "unpinned" ? "unpinned" : null };
      const icon = iconNode(name, iconArgs);

      const attributes = {
        title: escapeExpression(i18n(`topic_statuses.${key}.help`)),
      };
      let klass = "topic-status";
      if (key === "unpinned" || key === "pinned") {
        klass += `.pin-toggle-button.${key}`;
      }
      result.push(h(`${canAct ? "a" : "span"}.${klass}`, attributes, icon));
    });

    return result;
  },

  click(e) {
    const parent = e.target.closest(".topic-statuses");
    if (parent?.querySelector(".pin-toggle-button")?.contains(e.target)) {
      this.attrs.topic.togglePinnedForUser();
    }
  },
});
