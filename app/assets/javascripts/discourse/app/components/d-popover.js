import Component from "@glimmer/component";
import { iconHTML } from "discourse-common/lib/icon-library";
import tippy from "tippy.js";
import { guidFor } from "@ember/object/internals";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { hideOnEscapePlugin } from "discourse/lib/d-popover";
import { isPresent } from "@ember/utils";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

export default class DiscoursePopover extends Component {
  @tracked isExpanded = false;

  @service appEvents;

  constructor() {
    super(...arguments);

    this.appEvents.on("d-popover:close", this, this.close);
  }

  willDestroy() {
    super.willDestroy(...arguments);

    this.appEvents.off("d-popover:close", this, this.close);
  }

  @action
  setupTippy(element) {
    this._tippyInstance = this._setupTippy(element);
  }

  @action
  teardownTippy() {
    this._tippyInstance?.destroy();
  }

  @action
  computeIsExpanded() {
    if (isPresent(this.args.isExpanded)) {
      this.isExpanded = this.args.isExpanded;
    }
  }

  get componentId() {
    return guidFor(this);
  }

  @action
  close(event) {
    event?.preventDefault();
    this._tippyInstance?.hide();
  }

  _setupTippy(element) {
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
        element.querySelector(
          ":scope > .d-popover-content, :scope > div, :scope > ul"
        ),
      onShow: () => {
        next(() => {
          if (this.isDestroyed || this.isDestroying) {
            return;
          }

          this.isExpanded = true;
        });
        return true;
      },
      onHide: () => {
        next(() => {
          if (this.isDestroyed || this.isDestroying) {
            return;
          }
          this.isExpanded = false;
        });
        return true;
      },
    };

    const target = element.querySelector(
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
