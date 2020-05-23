import I18n from "I18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { computed, action } from "@ember/object";

const UNPINNED = "unpinned";
const PINNED = "pinned";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["pinned-options"],
  classNames: ["pinned-options"],

  selectKitOptions: {
    showCaret: true
  },

  modifySelection(content) {
    const pinnedGlobally = this.get("topic.pinned_globally");
    const pinned = this.value;
    const globally = pinnedGlobally ? "_globally" : "";
    const state = pinned ? `pinned${globally}` : UNPINNED;
    const title = I18n.t(`topic_statuses.${state}.title`);

    content.label = `<span>${title}</span>`.htmlSafe();
    content.title = title;
    content.name = state;
    content.icon = `thumbtack${state === UNPINNED ? " unpinned" : ""}`;
    return content;
  },

  content: computed(function() {
    const globally = this.topic.pinned_globally ? "_globally" : "";

    return [
      {
        id: PINNED,
        name: I18n.t(`topic_statuses.pinned${globally}.title`),
        description: this.site.mobileView
          ? null
          : I18n.t(`topic_statuses.pinned${globally}.help`),
        icon: "thumbtack"
      },
      {
        id: UNPINNED,
        name: I18n.t("topic_statuses.unpinned.title"),
        icon: "thumbtack unpinned",
        description: this.site.mobileView
          ? null
          : I18n.t("topic_statuses.unpinned.help")
      }
    ];
  }),

  @action
  onChange(value) {
    const topic = this.topic;

    if (value === UNPINNED) {
      return topic.clearPin();
    } else {
      return topic.rePin();
    }
  }
});
