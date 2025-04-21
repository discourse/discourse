import { action, computed } from "@ember/object";
import { htmlSafe } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

const UNPINNED = "unpinned";
const PINNED = "pinned";

@classNames("pinned-options")
@selectKitOptions({
  showCaret: true,
})
@pluginApiIdentifiers("pinned-options")
export default class PinnedOptions extends DropdownSelectBoxComponent {
  modifySelection(content) {
    const pinnedGlobally = this.get("topic.pinned_globally");
    const pinned = this.value;
    const globally = pinnedGlobally ? "_globally" : "";
    const state = pinned ? `pinned${globally}` : UNPINNED;
    const title = i18n(`topic_statuses.${state}.title`);

    content.label = htmlSafe(`<span>${title}</span>`);
    content.title = title;
    content.name = state;
    content.icon = `thumbtack${state === UNPINNED ? " unpinned" : ""}`;
    return content;
  }

  @computed
  get content() {
    const globally = this.topic.pinned_globally ? "_globally" : "";

    return [
      {
        id: PINNED,
        name: i18n(`topic_statuses.pinned${globally}.title`),
        description: this.site.mobileView
          ? null
          : i18n(`topic_statuses.pinned${globally}.help`),
        icon: "thumbtack",
      },
      {
        id: UNPINNED,
        name: i18n("topic_statuses.unpinned.title"),
        icon: "thumbtack unpinned",
        description: this.site.mobileView
          ? null
          : i18n("topic_statuses.unpinned.help"),
      },
    ];
  }

  @action
  onChange(value) {
    const topic = this.topic;

    if (value === UNPINNED) {
      return topic.clearPin();
    } else {
      return topic.rePin();
    }
  }
}
