import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Ember.Controller.extend(ModalFunctionality, {
  linkUrl: "",
  linkText: "",

  onShow() {
    Ember.run.next(() =>
      $(this)
        .find("input.link-url")
        .focus()
    );
  },

  actions: {
    ok() {
      const origLink = this.linkUrl;
      const linkUrl =
        origLink.indexOf("://") === -1 ? `http://${origLink}` : origLink;
      const sel = this._lastSel;

      if (Ember.isEmpty(linkUrl)) {
        return;
      }

      const linkText = this.linkText || "";

      if (linkText.length) {
        this.toolbarEvent.addText(`[${linkText}](${linkUrl})`);
      } else {
        if (sel.value) {
          this.toolbarEvent.addText(`[${sel.value}](${linkUrl})`);
        } else {
          this.toolbarEvent.addText(`[${origLink}](${linkUrl})`);
          this.toolbarEvent.selectText(sel.start + 1, origLink.length);
        }
      }
      this.set("linkUrl", "");
      this.set("linkText", "");
      this.send("closeModal");
    },
    cancel() {
      this.send("closeModal");
    }
  }
});
