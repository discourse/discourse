import { cookAsync } from "discourse/lib/text";

export default Ember.Component.extend({
  didInsertElement() {
    this._super(...arguments);

    const contents = $(this.element).html();
    cookAsync(contents).then((cooked) => $(this.element).html(cooked.string));
  },
});
