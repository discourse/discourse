import DropdownSelectBoxComponent from "select-box-kit/components/dropdown-select-box";
import computed from "ember-addons/ember-computed-decorators";
import { observes } from "ember-addons/ember-computed-decorators";
import { iconHTML } from "discourse-common/lib/icon-library";

export default DropdownSelectBoxComponent.extend({
  classNames: "pinned-options",

  @computed("topic.pinned")
  value(pinned) {
    return pinned ? "pinned" : "unpinned";
  },

  @observes("topic.pinned")
  _pinStateChanged() {
    this.set("value", this.get("topic.pinned") ? "pinned" : "unpinned");
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

  @computed("topic.pinned", "topic.pinned_globally")
  headerIcon(pinned, pinnedGlobally) {
    const globally = pinnedGlobally ? "_globally" : "";
    const state = pinned ? `pinned${globally}` : "unpinned";

    return iconHTML(
      "thumb-tack",
      { class: (state === "unpinned" ? "unpinned" : null) }
    );
  },

  @computed("topic.pinned", "topic.pinned_globally")
  headerText(pinned, pinnedGlobally) {
    const globally = pinnedGlobally ? "_globally" : "";
    const state = pinned ? `pinned${globally}` : "unpinned";
    const title = I18n.t(`topic_statuses.${state}.title`);

    return `${title}${iconHTML("caret-down")}`.htmlSafe();
  },

  actions: {
    onSelect(value) {
      this.defaultOnSelect();

      const topic = this.get("topic");

      if (value === "unpinned") {
        topic.clearPin();
      } else {
        topic.rePin();
      }
    }
  }
});
