
export default Discourse.View.extend({
  didInsertElement: function() {
    var path = this.get('controller.model.path');
    if(path === "faq" || path === "guidelines"){
      var $window = $(window);
      $window.on('scroll.faq', function(){
        if($window.scrollTop() + $window.height() > $(document).height() - 10) {
          if(!this._notifiedBottom){
            this._notifiedBottom = true;
            Discourse.ajax("/users/read-faq", {
              method: "POST"
            });
          }
        }
      });
    }
  },
  willDestroyElement: function(){
    $(window).off('scroll.faq');
  }
});
