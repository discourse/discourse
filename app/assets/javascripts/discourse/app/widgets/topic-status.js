import I18n from "I18n";
import TopicStatusIcons from "discourse/helpers/topic-status-icons";
import { createWidget } from "discourse/widgets/widget";
import { escapeExpression } from "discourse/lib/utilities";
import { h } from "virtual-dom";
import { iconNode } from "discourse-common/lib/icon-library";

export default createWidget("topic-status", {
  tagName: "span.topic-statuses",

  html(attrs) {
    const topic = attrs.topic;
    const canAct = this.currentUser && !attrs.disableActions;

    const result = [];

    TopicStatusIcons.render(topic, function (name, key) {
      const iconArgs = key === "unpinned" ? { class: "unpinned" } : null;
      const icon = iconNode(name, iconArgs);

      const attributes = {
        title: escapeExpression(I18n.t(`topic_statuses.${key}.help`)),
      };
      result.push(h(`${canAct ? "a" : "span"}.topic-status`, attributes, icon));
    });

    return result;
  },
});
