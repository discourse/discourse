// Remove when legacy modals are dropped (deprecation: discourse.modal-controllers)

import Component from "@glimmer/component";
import I18n from "I18n";
import { next, schedule } from "@ember/runloop";
import { bind } from "discourse-common/utils/decorators";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

@disableImplicitInjections
export default class DModal extends Component {
  @service appEvents;
  @service modal;

  @tracked wrapperElement;
  @tracked modalBodyData = {};
  @tracked flash;

  get modalStyle() {
    if (this.args.modalStyle === "inline-modal") {
      return "inline-modal";
    } else {
      return "fixed-modal";
    }
  }

  get submitOnEnter() {
    if ("submitOnEnter" in this.modalBodyData) {
      return this.modalBodyData.submitOnEnter;
    } else {
      return true;
    }
  }

  get dismissable() {
    if ("dismissable" in this.modalBodyData) {
      return this.modalBodyData.dismissable;
    } else {
      return true;
    }
  }

  get title() {
    if (this.modalBodyData.title) {
      return I18n.t(this.modalBodyData.title);
    } else if (this.modalBodyData.rawTitle) {
      return this.modalBodyData.rawTitle;
    } else {
      return this.args.title;
    }
  }

  get subtitle() {
    if (this.modalBodyData.subtitle) {
      return I18n.t(this.modalBodyData.subtitle);
    }

    return this.modalBodyData.rawSubtitle || this.args.subtitle;
  }

  get headerClass() {
    return this.modalBodyData.headerClass;
  }

  get panels() {
    return this.args.panels;
  }

  get errors() {
    return this.args.errors;
  }

  @action
  setupListeners(element) {
    this.appEvents.on("modal:body-shown", this._modalBodyShown);
    this.appEvents.on("modal-body:flash", this._flash);
    this.appEvents.on("modal-body:clearFlash", this._clearFlash);
    document.documentElement.addEventListener(
      "keydown",
      this._handleModalEvents
    );
    this.wrapperElement = element;
  }

  @action
  cleanupListeners() {
    this.appEvents.off("modal:body-shown", this._modalBodyShown);
    this.appEvents.off("modal-body:flash", this._flash);
    this.appEvents.off("modal-body:clearFlash", this._clearFlash);
    document.documentElement.removeEventListener(
      "keydown",
      this._handleModalEvents
    );
  }

  get ariaLabelledby() {
    if (this.modalBodyData.titleAriaElementId) {
      return this.modalBodyData.titleAriaElementId;
    } else if (this.args.titleAriaElementId) {
      return this.args.titleAriaElementId;
    } else if (this.args.title) {
      return "discourse-modal-title";
    }
  }

  get modalClass() {
    return this.modalBodyData.modalClass || this.args.modalClass;
  }

  triggerClickOnEnter(e) {
    if (!this.submitOnEnter) {
      return false;
    }

    // skip when in a form or a textarea element
    if (
      e.target.closest("form") ||
      (document.activeElement && document.activeElement.nodeName === "TEXTAREA")
    ) {
      return false;
    }

    return true;
  }

  @action
  handleMouseDown(e) {
    if (!this.dismissable) {
      return;
    }

    if (
      e.target.classList.contains("modal-middle-container") ||
      e.target.classList.contains("modal-outer-container")
    ) {
      // Send modal close (which bubbles to ApplicationRoute) if clicked outside.
      // We do this because some CSS of ours seems to cover the backdrop and makes
      // it unclickable.
      return this.args.closeModal?.("initiatedByClickOut");
    }
  }

  @bind
  _modalBodyShown(data) {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    if (data.fixed) {
      this.modal.hidden = false;
    }

    this.modalBodyData = data;

    next(() => {
      schedule("afterRender", () => {
        this._trapTab();
      });
    });
  }

  @bind
  _handleModalEvents(event) {
    if (this.args.hidden) {
      return;
    }

    if (event.key === "Escape" && this.dismissable) {
      next(() => this.args.closeModal("initiatedByESC"));
    }

    if (event.key === "Enter" && this.triggerClickOnEnter(event)) {
      this.wrapperElement.querySelector(".modal-footer .btn-primary")?.click();
      event.preventDefault();
    }

    if (event.key === "Tab") {
      this._trapTab(event);
    }
  }

  _trapTab(event) {
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

  @bind
  _clearFlash() {
    this.flash = null;
  }

  @bind
  _flash(msg) {
    this.flash = msg;
  }
}
