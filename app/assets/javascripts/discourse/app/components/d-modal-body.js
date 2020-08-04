import { scheduleOnce } from "@ember/runloop";
import Component from "@ember/component";
export default Component.extend({
  classNames: ["modal-body"],
  fixed: false,
  dismissable: true,

  didInsertElement() {
    this._super(...arguments);
    $("#modal-alert").hide();

    let fixedParent = $(this.element).closest(".d-modal.fixed-modal");
    if (fixedParent.length) {
      this.set("fixed", true);
      fixedParent.modal("show");
    }

    scheduleOnce("afterRender", this, this._afterFirstRender);
    this.appEvents.on("modal-body:flash", this, "_flash");
    this.appEvents.on("modal-body:clearFlash", this, "_clearFlash");
  },

  willDestroyElement() {
    this._super(...arguments);
    this.appEvents.off("modal-body:flash", this, "_flash");
    this.appEvents.off("modal-body:clearFlash", this, "_clearFlash");
    this.appEvents.trigger("modal:body-dismissed");
  },

  _afterFirstRender() {
    if (
      !this.site.mobileView &&
      this.autoFocus !== "false" &&
      this.element.querySelector("input")
    ) {
      this.element.querySelector("input").focus();
    }

    const maxHeight = this.maxHeight;
    if (maxHeight) {
      const maxHeightFloat = parseFloat(maxHeight) / 100.0;
      if (maxHeightFloat > 0) {
        const viewPortHeight = $(window).height();
        $(this.element).css(
          "max-height",
          Math.floor(maxHeightFloat * viewPortHeight) + "px"
        );
      }
    }

    this.appEvents.trigger(
      "modal:body-shown",
      this.getProperties(
        "title",
        "rawTitle",
        "fixed",
        "subtitle",
        "rawSubtitle",
        "dismissable"
      )
    );
  },

  _clearFlash() {
    $("#modal-alert")
      .hide()
      .removeClass("alert-error", "alert-success");
  },

  _flash(msg) {
    this._clearFlash();

    $("#modal-alert")
      .addClass(`alert alert-${msg.messageClass || "success"}`)
      .html(msg.text || "")
      .fadeIn();
  }
});
