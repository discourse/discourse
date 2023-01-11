import Component from "@ember/component";
import { cookAsync } from "discourse/lib/text";

export default Component.extend({
  didInsertElement() {
    this._super(...arguments);

    const contents = $(this.element).html();
    cookAsync(contents).then((cooked) => $(this.element).html(cooked.string));
  },
});
