import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";
import tippy from "tippy.js";
import { guidFor } from "@ember/object/internals";

export default class DiscoursePopover extends Component {
  tagName = "";

  isExpanded = false;

  options = null;

  class = null;

  didInsertElement() {
    this._super(...arguments);

    this._setupTippy();
  }

  get componentId() {
    return guidFor(this);
  }

  _setupTippy() {
    const baseOptions = {
      trigger: "click",
      zIndex: 1400,
      arrow: iconHTML("tippy-rounded-arrow"),
      interactive: true,
      allowHTML: false,
      appendTo: "parent",
      content:
        this.options?.content ||
        document
          .getElementById(this.componentId)
          .querySelector(
            ":scope > .d-popover-content, :scope > div, :scope > ul"
          ),
      onShow: () => {
        if (this.isDestroyed || this.isDestroying) {
          return;
        }
        this.set("isExpanded", true);
      },
      onHide: () => {
        if (this.isDestroyed || this.isDestroying) {
          return;
        }
        this.set("isExpanded", false);
      },
    };

    tippy(
      document
        .getElementById(this.componentId)
        .querySelector(
          ':scope > .d-popover-trigger, :scope > .btn, :scope > [role="button"]'
        ),
      Object.assign({}, baseOptions, this.options || {})
    );
  }
}
