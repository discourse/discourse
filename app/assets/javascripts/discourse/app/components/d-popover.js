import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";
import tippy from "tippy.js";
import { guidFor } from "@ember/object/internals";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { hideOnEscapePlugin } from "discourse/lib/d-popover";

export default class DiscoursePopover extends Component {
  tagName = "";

  isExpanded = false;

  options = null;

  class = null;

  didInsertElement() {
    this._super(...arguments);

    this._tippyInstance = this._setupTippy();
  }

  willDestroyElement() {
    this._super(...arguments);

    this._tippyInstance?.destroy();
  }

  get componentId() {
    return guidFor(this);
  }

  @action
  close(event) {
    event.preventDefault();

    if (!this.isExpanded) {
      return;
    }

    this._tippyInstance?.hide();
  }

  _setupTippy() {
    const baseOptions = {
      trigger: "click",
      zIndex: 1400,
      arrow: iconHTML("tippy-rounded-arrow"),
      interactive: true,
      allowHTML: false,
      appendTo: "parent",
      hideOnClick: true,
      plugins: [hideOnEscapePlugin],
      content:
        this.options?.content ||
        document
          .getElementById(this.componentId)
          .querySelector(
            ":scope > .d-popover-content, :scope > div, :scope > ul"
          ),
      onShow: () => {
        next(() => {
          if (this.isDestroyed || this.isDestroying) {
            return;
          }

          this.set("isExpanded", true);
        });
        return true;
      },
      onHide: () => {
        next(() => {
          if (this.isDestroyed || this.isDestroying) {
            return;
          }
          this.set("isExpanded", false);
        });
        return true;
      },
    };

    const target = document
      .getElementById(this.componentId)
      .querySelector(
        ':scope > .d-popover-trigger, :scope > .btn, :scope > [role="button"]'
      );

    if (!target) {
      return null;
    }

    const instance = tippy(
      target,
      Object.assign({}, baseOptions, this.options || {})
    );

    return instance?.id ? instance : null;
  }
}
