import isElementInViewport from "discourse/lib/is-element-in-viewport";
import ScrollTop from 'discourse/mixins/scroll-top';
import { on } from 'ember-addons/ember-computed-decorators';

export default Ember.View.extend(ScrollTop, {

  @on('didInsertElement')
  _checkRead() {
    const currentUser = this.get('controller.currentUser');
    if (currentUser) {
      const path = this.get('controller.model.path');
      if (path === "faq" || path === "guidelines") {
        const controller = this.get('controller');
        $(window).on('load.faq resize.faq scroll.faq', function() {
          const faqUnread = !currentUser.get('read_faq');
          if (faqUnread && isElementInViewport($(".contents p").last())) {
            controller.send('markFaqRead');
          }
        });
      }
    }
  },

  @on('willDestroyElement')
  _stopChecking() {
    $(window).off('load.faq resize.faq scroll.faq');
  }
});
