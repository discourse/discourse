import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { on } from "ember-addons/ember-computed-decorators";
import { iconHTML } from "discourse-common/lib/icon-library";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["pinned-options"],
  classNames: "pinned-options",
  allowInitialValueMutation: false,

  autoHighlight() {},

  computeHeaderContent() {
    let content = this._super(...arguments);
    const pinnedGlobally = this.get("topic.pinned_globally");
    const pinned = this.get("computedValue");
    const globally = pinnedGlobally ? "_globally" : "";
    const state = pinned ? `pinned${globally}` : "unpinned";
    const title = I18n.t(`topic_statuses.${state}.title`);

    content.label = `${title}${iconHTML("caret-down")}`.htmlSafe();
    content.title = title;
    content.name = state;
    content.icon = `thumbtack${state === "unpinned" ? " unpinned" : ""}`;
    return content;
  },

  @on("init")
  _setContent() {
    const globally = this.get("topic.pinned_globally") ? "_globally" : "";

    this.set("content", [
      {
        id: "pinned",
        name: I18n.t("topic_statuses.pinned" + globally + ".title"),
        description: I18n.t("topic_statuses.pinned" + globally + ".help"),
        icon: "thumbtack"
      },
      {
        id: "unpinned",
        name: I18n.t("topic_statuses.unpinned.title"),
        icon: "thumbtack unpinned",
        description: I18n.t("topic_statuses.unpinned.help")
      }
    ]);
  },

  actions: {
    onSelect() {
      const topic = this.get("topic");

      if (this.get("computedValue") === "unpinned") {
        topic.clearPin();
      } else {
        topic.rePin();
      }
    }
  }
});
