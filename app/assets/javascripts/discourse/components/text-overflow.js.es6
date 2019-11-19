import { next } from "@ember/runloop";
import Component from "@ember/component";
export default Component.extend({
  didInsertElement() {
    this._super(...arguments);
    next(null, () => {
      const $this = $(this.element);

      if ($this) {
        $this.find("hr").remove();
        $this.ellipsis();
      }
    });
  }
});
