/* You might be looking for navigation-item. */
import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  classNames: ['item'],
  tagName: "div",
  router: Ember.inject.service(),
  items: null,
  actions: {
    removeItem(item) {
      this.get("onRemoveItem")(item);
    }
  }
});
