import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { on } from "ember-addons/ember-computed-decorators";
import { iconHTML } from 'discourse-common/lib/icon-library';

export default DropdownSelectBoxComponent.extend({
  classNames: "pinned-options",
  allowInitialValueMutation: false,

  autoHighlight() {},

  computeHeaderContent() {
    let content = this.baseHeaderComputedContent();
    const pinnedGlobally = this.get("topic.pinned_globally");
    const pinned = this.get("computedValue");
    const globally = pinnedGlobally ? "_globally" : "";
    const state = pinned ? `pinned${globally}` : "unpinned";
    const title = I18n.t(`topic_statuses.${state}.title`);

    content.name = `${title}${iconHTML("caret-down")}`.htmlSafe();
    content.dataName = title;

    content.icons = [
      iconHTML("thumb-tack", {
        class: (state === "unpinned" ? "unpinned" : null)
      }).htmlSafe()
    ];

    return content;
  },

  @on("init")
  _setContent() {
    const globally = this.get("topic.pinned_globally") ? "_globally" : "";

    this.set("content", [
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
    ]);
  },

  mutateValue(value) {
    const topic = this.get("topic");

    if (value === "unpinned") {
      topic.clearPin();
    } else {
      topic.rePin();
    }
  }
});
