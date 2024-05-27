import Component from "@ember/component";
import $ from "jquery";
import { cook } from "discourse/lib/text";

export default Component.extend({
  didInsertElement() {
    this._super(...arguments);

    const contents = $(this.element).html();
    cook(contents).then((cooked) => $(this.element).html(cooked.toString()));
  },
});
