import Component from "@ember/component";
export default Component.extend({
  keyPress(e) {
    e.stopPropagation();
  }
});
