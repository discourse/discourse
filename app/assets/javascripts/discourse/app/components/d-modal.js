import Component from "@glimmer/component";
import ClassicComponent from "@ember/component";
import { action } from "@ember/object";
import { cached, tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";

export const CLOSE_INITIATED_BY_BUTTON = "initiatedByCloseButton";
export const CLOSE_INITIATED_BY_ESC = "initiatedByESC";
export const CLOSE_INITIATED_BY_CLICK_OUTSIDE = "initiatedByClickOut";
export const CLOSE_INITIATED_BY_MODAL_SHOW = "initiatedByModalShow";

const FLASH_TYPES = ["success", "error", "warning", "info"];

export default class DModal extends Component {
  @service modal;
  @tracked wrapperElement;

  @action
  setupListeners(element) {
    document.documentElement.addEventListener(
      "keydown",
      this.handleDocumentKeydown
    );
    this.wrapperElement = element;
  }

  @action
  cleanupListeners() {
    document.documentElement.removeEventListener(
      "keydown",
      this.handleDocumentKeydown
    );
  }

  get dismissable() {
    if (!this.args.closeModal) {
      return false;
    } else if ("dismissable" in this.args) {
      return this.args.dismissable;
    } else {
      return true;
    }
  }

  shouldTriggerClickOnEnter(event) {
    if (this.args.submitOnEnter === false) {
      return false;
    }

    // skip when in a form or a textarea element
    if (
      event.target.closest("form") ||
      document.activeElement?.nodeName === "TEXTAREA"
    ) {
      return false;
    }

    return true;
  }

  @action
  handleWrapperClick(e) {
    if (e.button !== 0) {
      return; // Non-default mouse button
    }

    if (!this.dismissable) {
      return;
    }

    return this.args.closeModal?.({
      initiatedBy: CLOSE_INITIATED_BY_CLICK_OUTSIDE,
    });
  }

  @action
  handleDocumentKeydown(event) {
    if (this.args.hidden) {
      return;
    }

    if (event.key === "Escape" && this.dismissable) {
      event.stopPropagation();
      this.args.closeModal({ initiatedBy: CLOSE_INITIATED_BY_ESC });
    }

    if (event.key === "Enter" && this.shouldTriggerClickOnEnter(event)) {
      this.wrapperElement.querySelector(".modal-footer .btn-primary")?.click();
      event.preventDefault();
    }
  }

  @action
  handleCloseButton() {
    this.args.closeModal({ initiatedBy: CLOSE_INITIATED_BY_BUTTON });
  }

  @action
  validateFlashType(type) {
    if (type && !FLASH_TYPES.includes(type)) {
      throw `@flashType must be one of ${FLASH_TYPES.join(", ")}`;
    }
  }

  // Could be optimised to remove classic component once RFC389 is implemented
  // https://rfcs.emberjs.com/id/0389-dynamic-tag-names
  @cached
  get dynamicElement() {
    const tagName = this.args.tagName || "div";
    if (!["div", "form"].includes(tagName)) {
      throw `@tagName must be form or div`;
    }

    return class WrapperComponent extends ClassicComponent {
      tagName = tagName;
    };
  }
}
