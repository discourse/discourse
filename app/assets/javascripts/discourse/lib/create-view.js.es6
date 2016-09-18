import { on } from 'ember-addons/ember-computed-decorators';

export function createViewWithBodyClass(body_class) {
  return Ember.View.extend({
    @on("didInsertElement")
    addBodyClass() {
      $('body').addClass(body_class);
    },

    @on("willDestroyElement")
    removeBodyClass() {
      $('body').removeClass(body_class);
    }
  });
}
