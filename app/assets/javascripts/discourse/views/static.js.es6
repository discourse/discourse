var readFaq = false;

export default Ember.View.extend(Discourse.ScrollTop, {
  _checkRead: function() {
    var path = this.get('controller.model.path');
    if(path === "faq" || path === "guidelines"){
      var $window = $(window),
          controller = this.get('controller');
      $window.on('scroll.faq', function(){
        if(!readFaq && ($window.scrollTop() + $window.height() > $(document).height() - 10)) {
          readFaq = true;
          controller.send('markFaqRead');
        }
      });
    }
  }.on('didInsertElement'),

  _stopChecking: function(){
    $(window).off('scroll.faq');
  }.on('willDestroyElement')
});
