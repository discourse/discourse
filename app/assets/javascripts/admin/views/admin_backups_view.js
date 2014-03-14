Discourse.AdminBackupsView = Discourse.View.extend({
  classNames: ["admin-backups"],

  _hijackDownloads: function() {
    this.$().on("mouseup.admin-backups", "a.download", function (e) {
      var $link = $(e.currentTarget);

      $link.data("auto-route", true);

      Discourse.URL.redirectTo($link.attr("href"));
    });
  }.on("didInsertElement"),

  _removeBindings: function() {
    this.$().off("mouseup.admin-backups");
  }.on("willDestroyElement")

});
