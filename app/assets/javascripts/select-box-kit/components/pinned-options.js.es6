import DropdownSelectBoxComponent from "select-box-kit/components/dropdown-select-box";
import computed from "ember-addons/ember-computed-decorators";
import { observes } from "ember-addons/ember-computed-decorators";
import { on } from "ember-addons/ember-computed-decorators";

export default DropdownSelectBoxComponent.extend({
  classNames: "pinned-options",

  headerComponent: "pinned-options/pinned-options-header",

  @on("didReceiveAttrs")
  _setComponentOptions() {
    this.set("headerComponentOptions", Ember.Object.create({
      pinned: this.get("topic.pinned"),
      pinnedGlobally: this.get("topic.pinned_globally")
    }));
  },

  @computed("topic.pinned")
  value(pinned) {
    return pinned ? "pinned" : "unpinned";
  },

  @observes("topic.pinned")
  _pinStateChanged() {
    this.set("value", this.get("topic.pinned") ? "pinned" : "unpinned");
    this._setComponentOptions();
  },

  @computed("topic.pinned_globally")
  content(pinnedGlobally) {
    const globally = pinnedGlobally ? "_globally" : "";

    return [
      {
        id: "pinned",
        name: I18n.t("topic_statuses.pinned" + globally + ".title"),
        description: I18n.t('topic_statuses.pinned' + globally + '.help'),
        icon: "thumb-tack"
      },
      {
        id: "unpinned",
        name: I18n.t("topic_statuses.unpinned.title"),
        icon: "thumb-tack",
        description: I18n.t('topic_statuses.unpinned.help'),
        iconClass: "unpinned"
      }
    ];
  },

  actions: {
    onSelect(value) {
      value = this.defaultOnSelect(value);

      const topic = this.get("topic");

      if (value === "unpinned") {
        topic.clearPin();
      } else {
        topic.rePin();
      }
    }
  }
});
