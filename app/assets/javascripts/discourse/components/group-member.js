import Component from "@ember/component";
export default Component.extend({
  classNames: ["item"],

  actions: {
    remove() {
      this.removeAction(this.member);
    }
  }
});
