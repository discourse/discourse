import { next } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import Component from "@ember/component";

export default Component.extend({
  text: null,

  init() {
    this._super(...arguments);

    this.set("text", htmlSafe(this.text));
  },

  didInsertElement() {
    this._super(...arguments);

    next(null, () => {
      const $this = $(this.element);

      if ($this) {
        $this.find("br").replaceWith(" ");
        $this.find("hr").remove();
        $this.ellipsis();
      }
    });
  }
});
