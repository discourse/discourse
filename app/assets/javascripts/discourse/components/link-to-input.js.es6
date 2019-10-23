import Component from "@ember/component";
export default Component.extend({
  showInput: false,

  click() {
    this.onClick();

    Ember.run.schedule("afterRender", () => {
      $(this.element)
        .find("input")
        .focus();
    });

    return false;
  }
});
