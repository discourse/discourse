import Component from "@ember/component";

export default Component.extend({
  click(event) {
    event.preventDefault();
    event.stopPropagation();
  }
});
