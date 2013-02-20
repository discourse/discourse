(function() {

  window.Discourse.UserActionGroup = Discourse.Model.extend({
    push: function(item) {
      if (!this.items) {
        this.items = [];
      }
      return this.items.push(item);
    }
  });

}).call(this);
