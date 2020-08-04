import { schedule } from "@ember/runloop";
import Component from "@ember/component";
export default Component.extend({
  showInput: false,

  click() {
    this.onClick();

    schedule("afterRender", () => {
      $(this.element)
        .find("input")
        .focus();
    });

    return false;
  }
});
