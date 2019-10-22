import { on } from "ember-addons/ember-computed-decorators";
import Component from "@ember/component";

export default Component.extend({
  classNameBindings: [
    ":modal",
    ":d-modal",
    "modalClass",
    "modalStyle",
    "hasPanels"
  ],
  attributeBindings: ["data-keyboard"],
  dismissable: true,
  title: null,
  subtitle: null,

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

  @on("didInsertElement")
  setUp() {
    $("html").on("keydown.discourse-modal", e => {
      if (e.which === 27 && this.dismissable) {
        Ember.run.next(() => $(".modal-header a.close").click());
      }

      if (e.which === 13 && this.triggerClickOnEnter(e)) {
        Ember.run.next(() => $(".modal-footer .btn-primary").click());
      }
    });

    this.appEvents.on("modal:body-shown", this, "_modalBodyShown");
  },

  @on("willDestroyElement")
  cleanUp() {
    $("html").off("keydown.discourse-modal");
    this.appEvents.off("modal:body-shown", this, "_modalBodyShown");
  },

  triggerClickOnEnter(e) {
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
      // Delegate click to modal close if clicked outside.
      // We do this because some CSS of ours seems to cover
      // the backdrop and makes it unclickable.
      $(".modal-header a.close").click();
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

    if ("dismissable" in data) {
      this.set("dismissable", data.dismissable);
    } else {
      this.set("dismissable", true);
    }
  }
});
