import { iconHTML } from "discourse-common/lib/icon-library";
import { bufferedRender } from "discourse-common/lib/buffered-render";
import { escapeExpression } from "discourse/lib/utilities";

export default Ember.Component.extend(
  bufferedRender({
    classNames: ["topic-statuses"],

    rerenderTriggers: [
      "topic.archived",
      "topic.closed",
      "topic.pinned",
      "topic.visible",
      "topic.unpinned",
      "topic.is_warning"
    ],

    click(e) {
      // only pin unpin for now
      if (this.get("canAct") && $(e.target).hasClass("d-icon-thumb-tack")) {
        const topic = this.get("topic");
        topic.get("pinned") ? topic.clearPin() : topic.rePin();
      }

      return false;
    },

    canAct: function() {
      return Discourse.User.current() && !this.get("disableActions");
    }.property("disableActions"),

    buildBuffer(buffer) {
      const renderIcon = function(name, key, actionable) {
        const title = escapeExpression(I18n.t(`topic_statuses.${key}.help`)),
          startTag = actionable ? "a href" : "span",
          endTag = actionable ? "a" : "span",
          iconArgs = key === "unpinned" ? { class: "unpinned" } : null,
          icon = iconHTML(name, iconArgs);

        buffer.push(
          `<${startTag} title='${title}' class='topic-status'>${icon}</${endTag}>`
        );
      };

      const renderIconIf = (conditionProp, name, key, actionable) => {
        if (!this.get(conditionProp)) {
          return;
        }
        renderIcon(name, key, actionable);
      };

      renderIconIf("topic.is_warning", "envelope", "warning");

      if (this.get("topic.closed") && this.get("topic.archived")) {
        renderIcon("lock", "locked_and_archived");
      } else {
        renderIconIf("topic.closed", "lock", "locked");
        renderIconIf("topic.archived", "lock", "archived");
      }

      renderIconIf("topic.pinned", "thumb-tack", "pinned", this.get("canAct"));
      renderIconIf(
        "topic.unpinned",
        "thumb-tack",
        "unpinned",
        this.get("canAct")
      );
      renderIconIf("topic.invisible", "eye-slash", "invisible");
    }
  })
);
