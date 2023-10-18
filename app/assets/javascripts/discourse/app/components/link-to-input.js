import Component from "@ember/component";
import { schedule } from "@ember/runloop";
import $ from "jquery";

export default Component.extend({
  showInput: false,

  click() {
    this.onClick();

    schedule("afterRender", () => {
      $(this.element).find("input").focus();
    });

    return false;
  },
});
