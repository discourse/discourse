import Component from "@glimmer/component";
import { iconHTML } from "discourse-common/lib/icon-library";
import tippy from "tippy.js";
import { action } from "@ember/object";
import { hideOnEscapePlugin } from "discourse/lib/d-popover";
import { tracked } from "@glimmer/tracking";

export default class ChatComposerDropdown extends Component {
  @tracked isExpanded = false;
  @tracked tippyInstance = null;

  trigger = null;

  @action
  setupTrigger(element) {
    this.trigger = element;
  }

  get ariaControls() {
    return this.tippyInstance?.popper?.id;
  }

  @action
  toggleExpand() {
    if (this.args.hasActivePanel) {
      this.args.onCloseActivePanel?.();
    } else {
      this.isExpanded = !this.isExpanded;
    }
  }

  @action
  onButtonClick(button) {
    this.tippyInstance.hide();
    button.action();
  }

  @action
  setupPanel(element) {
    this.tippyInstance = tippy(this.trigger, {
      theme: "chat-composer-dropdown",
      trigger: "click",
      zIndex: 1400,
      arrow: iconHTML("tippy-rounded-arrow"),
      interactive: true,
      allowHTML: false,
      appendTo: "parent",
      hideOnClick: true,
      plugins: [hideOnEscapePlugin],
      content: element,
      onShow: () => {
        this.isExpanded = true;
        return true;
      },
      onHide: () => {
        this.isExpanded = false;
        return true;
      },
    });

    this.tippyInstance.show();
  }

  @action
  teardownPanel() {
    this.tippyInstance?.destroy();
  }
}
