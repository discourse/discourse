(function() {

  Discourse.AdminEmailLogsRoute = Discourse.Route.extend({
    model: function() {
      return Discourse.EmailLog.findAll();
    }
  });

}).call(this);
