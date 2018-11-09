import { createWidget } from "discourse/widgets/widget";
import { iconNode } from "discourse-common/lib/icon-library";
import { h } from "virtual-dom";
import { escapeExpression } from "discourse/lib/utilities";

function renderIcon(name, key, canAct) {
  const iconArgs = key === "unpinned" ? { class: "unpinned" } : null,
    icon = iconNode(name, iconArgs);

  const attributes = {
    title: escapeExpression(I18n.t(`topic_statuses.${key}.help`))
  };
  return h(`${canAct ? "a" : "span"}.topic-status`, attributes, icon);
}

export default createWidget("topic-status", {
  tagName: "div.topic-statuses",

  html(attrs) {
    const topic = attrs.topic;
    const canAct = this.currentUser && !attrs.disableActions;

    const result = [];
    const renderIconIf = (conditionProp, name, key) => {
      if (!topic.get(conditionProp)) {
        return;
      }
      result.push(renderIcon(name, key, canAct));
    };

    renderIconIf("is_warning", "envelope", "warning");

    if (topic.get("closed") && topic.get("archived")) {
      renderIcon("lock", "locked_and_archived");
    } else {
      renderIconIf("closed", "lock", "locked");
      renderIconIf("archived", "lock", "archived");
    }

    renderIconIf("pinned", "thumb-tack", "pinned");
    renderIconIf("unpinned", "thumb-tack", "unpinned");
    renderIconIf("invisible", "eye-slash", "invisible");

    return result;
  }
});
