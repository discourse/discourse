import DiscourseURL from 'discourse/lib/url';

export default Ember.View.extend({
  classNames: ["admin-backups"],

  _hijackDownloads: function() {
    this.$().on("mouseup.admin-backups", "a.download", function (e) {
      var $link = $(e.currentTarget);

      if (!$link.data("href")) {
        $link.addClass("no-href");
        $link.data("href", $link.attr("href"));
        $link.attr("href", null);
        $link.data("auto-route", true);
      }

      DiscourseURL.redirectTo($link.data("href"));
    });
  }.on("didInsertElement"),

  _removeBindings: function() {
    this.$().off("mouseup.admin-backups");
  }.on("willDestroyElement")

});
