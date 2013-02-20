(function() {

  window.Discourse.VersionCheck = Discourse.Model.extend({});

  Discourse.VersionCheck.reopenClass({
    find: function() {
      var _this = this;
      return jQuery.ajax({
        url: '/admin/version_check',
        dataType: 'json',
        success: function(json) {
          return Discourse.VersionCheck.create(json);
        }
      });
    }
  });

}).call(this);
