export default Ember.Component.extend({
  showInput: false,

  click() {
    this.onClick();

    Ember.run.schedule("afterRender", () => {
      this.$()
        .find("input")
        .focus();
    });

    return false;
  }
});
