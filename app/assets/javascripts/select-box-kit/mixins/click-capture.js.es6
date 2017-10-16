export default Ember.Mixin.create({
  init() {
    this._super();

    this.captureMaskClass = "select-box-kit-click-capture-mask";
    this.captureMaskTemplate = `<div class="${this.captureMaskClass}" style="display: none;"></div>`;
  },

  willDestroyElement() {
    this._super();
    this.destroyClickCaptureMask();
  },

  setupClickCaptureMask() {
    if ($(`.${this.captureMaskClass}`).length === 0) {
      $("body").append(this.captureMaskTemplate);
    }

    $(`.${this.captureMaskClass}`)
      .off(`click.${this.elementId}`)
      .css("display", "block")
      .on(`click.${this.elementId}`, () => {
        this.close();
        return true;
      });
  },

  destroyClickCaptureMask() {
    $(`.${this.captureMaskClass}`)
      .off("mousedown touchstart click")
      .css("display", "none");
  }
});
