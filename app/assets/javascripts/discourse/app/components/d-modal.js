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
    this.trapTab();
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
  handleMouseUp(e) {
    if (e.button !== 0) {
      return; // Non-default mouse button
    }

    if (!this.dismissable) {
      return;
    }

    if (
      e.target.classList.contains("modal-middle-container") ||
      e.target.classList.contains("modal-outer-container")
    ) {
      return this.args.closeModal?.({
        initiatedBy: CLOSE_INITIATED_BY_CLICK_OUTSIDE,
      });
    }
  }

  @action
  handleDocumentKeydown(event) {
    if (this.args.hidden) {
      return;
    }

    if (event.key === "Escape" && this.dismissable) {
      this.args.closeModal({ initiatedBy: CLOSE_INITIATED_BY_ESC });
    }

    if (event.key === "Enter" && this.shouldTriggerClickOnEnter(event)) {
      this.wrapperElement.querySelector(".modal-footer .btn-primary")?.click();
      event.preventDefault();
    }

    if (event.key === "Tab") {
      this.trapTab(event);
    }
  }

  @action
  trapTab(event) {
    if (this.args.hidden) {
      return true;
    }

    const innerContainer = this.wrapperElement.querySelector(
      ".modal-inner-container"
    );
    if (!innerContainer) {
      return;
    }

    let focusableElements =
      '[autofocus], a, input, select, textarea, summary, [tabindex]:not([tabindex="-1"])';

    if (!event) {
      // on first trap we don't allow to focus modal-close
      // and apply manual focus only if we don't have any autofocus element
      const autofocusedElement = innerContainer.querySelector("[autofocus]");
      if (
        !autofocusedElement ||
        document.activeElement !== autofocusedElement
      ) {
        // if there's not autofocus, or the activeElement, is not the autofocusable element
        // attempt to focus the first of the focusable elements or just the modal-body
        // to make it possible to scroll with arrow down/up
        (
          autofocusedElement ||
          innerContainer.querySelector(
            focusableElements + ", button:not(.modal-close)"
          ) ||
          innerContainer.querySelector(".modal-body")
        )?.focus();
      }

      return;
    }

    focusableElements += ", button:enabled";

    const firstFocusableElement =
      innerContainer.querySelector(focusableElements);
    const focusableContent = innerContainer.querySelectorAll(focusableElements);
    const lastFocusableElement = focusableContent[focusableContent.length - 1];

    if (event.shiftKey) {
      if (document.activeElement === firstFocusableElement) {
        lastFocusableElement?.focus();
        event.preventDefault();
      }
    } else {
      if (document.activeElement === lastFocusableElement) {
        (
          innerContainer.querySelector(".modal-close") || firstFocusableElement
        )?.focus();
        event.preventDefault();
      }
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
