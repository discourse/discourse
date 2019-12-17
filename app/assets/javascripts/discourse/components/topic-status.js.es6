import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";

export default Component.extend({
  classNames: ["topic-statuses"],

  click(e) {
    // only pin unpin for now
    if (this.canAct && $(e.target).hasClass("d-icon-thumbtack")) {
      const topic = this.topic;
      topic.get("pinned") ? topic.clearPin() : topic.rePin();
    }

    return false;
  },

  @discourseComputed("disableActions")
  canAct(disableActions) {
    return this.currentUser && !disableActions;
  },

  @discourseComputed("topic.closed", "topic.archived")
  topicClosedArchived(closed, archived) {
    if (closed && archived) {
      this._set("closedArchived", "lock", "locked_and_archived");
      this._reset("closed");
      this._reset("archived");
      return true;
    } else {
      this._reset("closedArchived");
      closed ? this._set("closed", "lock", "locked") : this._reset("closed");
      archived
        ? this._set("archived", "lock", "archived")
        : this._reset("archived");
      return false;
    }
  },

  @discourseComputed("topic.is_warning")
  topicWarning(warning) {
    return warning
      ? this._set("warning", "envelope", "warning")
      : this._reset("warning");
  },

  @discourseComputed("topic.pinned")
  topicPinned(pinned) {
    return pinned
      ? this._set("pinned", "thumbtack", "pinned")
      : this._reset("pinned");
  },

  @discourseComputed("topic.unpinned")
  topicUnpinned(unpinned) {
    return unpinned
      ? this._set("unpinned", "thumbtack", "unpinned", { class: "unpinned" })
      : this._reset("unpinned");
  },

  @discourseComputed("topic.invisible")
  topicInvisible(invisible) {
    return invisible
      ? this._set("invisible", "far-eye-slash", "unlisted")
      : this._reset("invisible");
  },

  _set(name, icon, key, iconArgs = null) {
    this.set(`${name}Icon`, iconHTML(`${icon}`, iconArgs).htmlSafe());
    this.set(`${name}Title`, I18n.t(`topic_statuses.${key}.help`));
    return true;
  },

  _reset(name) {
    this.set(`${name}Icon`, null);
    this.set(`${name}Title`, null);
    return false;
  }
});
