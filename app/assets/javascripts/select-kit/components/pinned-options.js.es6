import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { iconHTML } from "discourse-common/lib/icon-library";
import { computed } from "@ember/object";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["pinned-options"],
  classNames: ["pinned-options"],

  modifySelection(content) {
    const pinnedGlobally = this.get("topic.pinned_globally");
    const pinned = this.value;
    const globally = pinnedGlobally ? "_globally" : "";
    const state = pinned === "pinned" ? `pinned${globally}` : "unpinned";
    const title = I18n.t(`topic_statuses.${state}.title`);

    content.label = `<span>${title}</span>${iconHTML("caret-down")}`.htmlSafe();
    content.title = title;
    content.name = state;
    content.icon = `thumbtack${state === "unpinned" ? " unpinned" : ""}`;
    return content;
  },

  content: computed(function() {
    const globally = this.topic.pinned_globally ? "_globally" : "";

    return [
      {
        id: "pinned",
        name: I18n.t(`topic_statuses.pinned${globally}.title`),
        description: this.site.mobileView
          ? null
          : I18n.t(`topic_statuses.pinned${globally}.help`),
        icon: "thumbtack"
      },
      {
        id: "unpinned",
        name: I18n.t("topic_statuses.unpinned.title"),
        icon: "thumbtack unpinned",
        description: this.site.mobileView
          ? null
          : I18n.t("topic_statuses.unpinned.help")
      }
    ];
  }),

  actions: {
    onSelect(value) {
      const topic = this.topic;

      if (value === "unpinned") {
        topic.clearPin();
      } else {
        topic.rePin();
      }
    }
  }
});
