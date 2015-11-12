import { on } from 'ember-addons/ember-computed-decorators';

const CATEGORIES_BODY_CLASS = "navigation-categories";

export default Ember.View.extend({
  @on("didInsertElement")
  addBodyClass() {
    $('body').addClass(CATEGORIES_BODY_CLASS);
  },

  @on("willDestroyElement")
  removeBodyClass() {
    $('body').removeClass(CATEGORIES_BODY_CLASS);
  },
});
