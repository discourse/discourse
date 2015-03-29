import isElementInViewport from "discourse/lib/is-element-in-viewport";

var readFaq = false;

export default Ember.View.extend(Discourse.ScrollTop, {

  _checkRead: function() {
    const path = this.get('controller.model.path');
    if (path === "faq" || path === "guidelines") {
      const controller = this.get('controller');
      $(window).on('load.faq resize.faq scroll.faq', function() {
        if (!readFaq && isElementInViewport($(".contents p").last())) {
          readFaq = true;
          controller.send('markFaqRead');
        }
      });
    }
  }.on('didInsertElement'),

  _stopChecking: function(){
    $(window).off('load.faq resize.faq scroll.faq');
  }.on('willDestroyElement')
});
