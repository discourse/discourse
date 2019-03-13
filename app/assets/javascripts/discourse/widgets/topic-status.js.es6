import { createWidget } from "discourse/widgets/widget";
import { iconNode } from "discourse-common/lib/icon-library";
import { h } from "virtual-dom";
import { escapeExpression } from "discourse/lib/utilities";
import TopicStatusIcons from "discourse/helpers/topic-status-icons";

export default createWidget("topic-status", {
  tagName: "div.topic-statuses",

  html(attrs) {
    const topic = attrs.topic;
    const canAct = this.currentUser && !attrs.disableActions;

    const result = [];

    TopicStatusIcons.render(topic, function(name, key) {
      const iconArgs = key === "unpinned" ? { class: "unpinned" } : null;
      const icon = iconNode(name, iconArgs);

      const attributes = {
        title: escapeExpression(I18n.t(`topic_statuses.${key}.help`))
      };
      result.push(h(`${canAct ? "a" : "span"}.topic-status`, attributes, icon));
    });

    return result;
  }
});
