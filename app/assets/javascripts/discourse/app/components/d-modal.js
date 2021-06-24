import { computed } from "@ember/object";
import Component from "@ember/component";
import I18n from "I18n";
import afterTransition from "discourse/lib/after-transition";
import { next } from "@ember/runloop";
import { on } from "discourse-common/utils/decorators";

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
  subtitle: null,
  role: "dialog",
  headerClass: null,

  init() {
    this._super(...arguments);

    // If we need to render a second modal for any reason, we can't
    // use `elementId`
    if (this.modalStyle !== "inline-modal") {
      this.set("elementId", "discourse-modal");
      this.set("modalStyle", "fixed-modal");
    }
  },

  // We handle ESC ourselves
  "data-keyboard": "false",
  // Inform screenreaders of the modal
  "aria-modal": "true",

  ariaLabelledby: computed("title", function () {
    return this.title ? "discourse-modal-title" : null;
  }),

  @on("didInsertElement")
  setUp() {
    $("html").on("keyup.discourse-modal", (e) => {
      // only respond to events when the modal is visible
      if (!this.element.classList.contains("hidden")) {
        if (e.which === 27 && this.dismissable) {
          next(() => this.attrs.closeModal("initiatedByESC"));
        }

        if (e.which === 13 && this.triggerClickOnEnter(e)) {
          next(() => $(".modal-footer .btn-primary").click());
        }
      }
    });

    this.appEvents.on("modal:body-shown", this, "_modalBodyShown");
  },

  @on("willDestroyElement")
  cleanUp() {
    $("html").off("keyup.discourse-modal");
    this.appEvents.off("modal:body-shown", this, "_modalBodyShown");
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
    const $target = $(e.target);
    if (
      $target.hasClass("modal-middle-container") ||
      $target.hasClass("modal-outer-container")
    ) {
      // Send modal close (which bubbles to ApplicationRoute) if clicked outside.
      // We do this because some CSS of ours seems to cover the backdrop and makes
      // it unclickable.
      return (
        this.attrs.closeModal && this.attrs.closeModal("initiatedByClickOut")
      );
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

    if (this.element && data.autoFocus) {
      let focusTarget = this.element.querySelector(
        ".modal-body input[autofocus]"
      );

      if (!focusTarget && !this.site.mobileView) {
        focusTarget = this.element.querySelector(
          ".modal-body input, .modal-body button, .modal-footer input, .modal-footer button"
        );

        if (!focusTarget) {
          focusTarget = this.element.querySelector(".modal-header button");
        }
      }
      if (focusTarget) {
        afterTransition(() => focusTarget.focus());
      }
    }
  },
});
