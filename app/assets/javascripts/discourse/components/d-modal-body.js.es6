export default Ember.Component.extend({
  classNames: ["modal-body"],
  fixed: false,
  dismissable: true,

  didInsertElement() {
    this._super(...arguments);
    $("#modal-alert").hide();

    let fixedParent = this.$().closest(".d-modal.fixed-modal");
    if (fixedParent.length) {
      this.set("fixed", true);
      fixedParent.modal("show");
    }

    Ember.run.scheduleOnce("afterRender", this, this._afterFirstRender);
    this.appEvents.on("modal-body:flash", msg => this._flash(msg));
    this.appEvents.on("modal-body:clearFlash", () => this._clearFlash());
  },

  willDestroyElement() {
    this._super(...arguments);
    this.appEvents.off("modal-body:flash");
    this.appEvents.off("modal-body:clearFlash");
  },

  _afterFirstRender() {
    if (!this.site.mobileView && this.get("autoFocus") !== "false") {
      this.$("input:first").focus();
    }

    const maxHeight = this.get("maxHeight");
    if (maxHeight) {
      const maxHeightFloat = parseFloat(maxHeight) / 100.0;
      if (maxHeightFloat > 0) {
        const viewPortHeight = $(window).height();
        this.$().css(
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
