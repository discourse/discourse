(function() {

  window.Discourse.AdminFlagsController = Ember.Controller.extend({
    clearFlags: function(item) {
      var _this = this;
      return item.clearFlags().then((function() {
        return _this.content.removeObject(item);
      }), (function() {
        return bootbox.alert("something went wrong");
      }));
    },
    deletePost: function(item) {
      var _this = this;
      return item.deletePost().then((function() {
        return _this.content.removeObject(item);
      }), (function() {
        return bootbox.alert("something went wrong");
      }));
    },
    adminOldFlagsView: (function() {
      return this.query === 'old';
    }).property('query'),
    adminActiveFlagsView: (function() {
      return this.query === 'active';
    }).property('query')
  });

}).call(this);
