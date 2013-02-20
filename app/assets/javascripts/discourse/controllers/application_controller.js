(function() {

  window.Discourse.ApplicationController = Ember.Controller.extend({
    needs: ['modal'],
    showLogin: function() {
      var _ref;
      return (_ref = this.get('controllers.modal')) ? _ref.show(Discourse.LoginView.create()) : void 0;
    }
  });

}).call(this);
