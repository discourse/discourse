import Component from "@ember/component";
import I18n from "I18n";
import { next, schedule } from "@ember/runloop";
import discourseComputed, { bind } from "discourse-common/utils/decorators";

export default Component.extend({
  classNameBindings: [
    ":modal",
    ":d-modal",
    "modalClass",
    "modalStyle",
    "hasPanels",
  ],
  attributeBindings: [
    "data-keyboard",
    "aria-modal",
    "role",
    "ariaLabelledby:aria-labelledby",
  ],
  submitOnEnter: true,
  dismissable: true,
  title: null,
  titleAriaElementId: null,
  subtitle: null,
  role: "dialog",
  headerClass: null,

  // We handle ESC ourselves
  "data-keyboard": "false",
  // Inform screen readers of the modal
  "aria-modal": "true",

  init() {
    this._super(...arguments);

    // If we need to render a second modal for any reason, we can't
    // use `elementId`
    if (this.modalStyle !== "inline-modal") {
      this.set("elementId", "discourse-modal");
      this.set("modalStyle", "fixed-modal");
    }
  },

  didInsertElement() {
    this._super(...arguments);

    this.appEvents.on("modal:body-shown", this, "_modalBodyShown");
    document.documentElement.addEventListener(
      "keydown",
      this._handleModalEvents
    );
  },

  willDestroyElement() {
    this._super(...arguments);

    this.appEvents.off("modal:body-shown", this, "_modalBodyShown");
    document.documentElement.removeEventListener(
      "keydown",
      this._handleModalEvents
    );
  },

  @discourseComputed("title", "titleAriaElementId")
  ariaLabelledby(title, titleAriaElementId) {
    if (titleAriaElementId) {
      return titleAriaElementId;
    }
    if (title) {
      return "discourse-modal-title";
    }

    return;
  },

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
  },

  mouseDown(e) {
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
      return this.attrs.closeModal?.("initiatedByClickOut");
    }
  },

  _modalBodyShown(data) {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    if (data.fixed) {
      this.element.classList.remove("hidden");
    }

    if (data.title) {
      this.set("title", I18n.t(data.title));
    } else if (data.rawTitle) {
      this.set("title", data.rawTitle);
    }

    if (data.subtitle) {
      this.set("subtitle", I18n.t(data.subtitle));
    } else if (data.rawSubtitle) {
      this.set("subtitle", data.rawSubtitle);
    } else {
      // if no subtitle provided, makes sure the previous subtitle
      // of another modal is not used
      this.set("subtitle", null);
    }

    if ("submitOnEnter" in data) {
      this.set("submitOnEnter", data.submitOnEnter);
    }

    if ("dismissable" in data) {
      this.set("dismissable", data.dismissable);
    } else {
      this.set("dismissable", true);
    }

    this.set("headerClass", data.headerClass || null);

    schedule("afterRender", () => {
      this._trapTab();
    });
  },

  @bind
  _handleModalEvents(event) {
    if (this.element.classList.contains("hidden")) {
      return;
    }

    if (event.key === "Escape" && this.dismissable) {
      next(() => this.attrs.closeModal("initiatedByESC"));
    }

    if (event.key === "Enter" && this.triggerClickOnEnter(event)) {
      this.element.querySelector(".modal-footer .btn-primary")?.click();
      event.preventDefault();
    }

    if (event.key === "Tab") {
      this._trapTab(event);
    }
  },

  _trapTab(event) {
    if (this.element.classList.contains("hidden")) {
      return true;
    }

    const innerContainer = this.element.querySelector(".modal-inner-container");
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
          innerContainer.querySelector(
            focusableElements + ", button:not(.modal-close)"
          ) || innerContainer.querySelector(".modal-body")
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
  },
});
