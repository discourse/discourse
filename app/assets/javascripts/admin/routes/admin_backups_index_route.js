Discourse.AdminBackupsIndexRoute = Discourse.Route.extend({

  model: function() {
    return Discourse.Backup.find();
  }

});
