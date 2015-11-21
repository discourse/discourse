const ScreenedUrl = Discourse.Model.extend({
  actionName: function() {
    return I18n.t("admin.logs.screened_actions." + this.get('action'));
  }.property('action')
});

ScreenedUrl.reopenClass({
  findAll: function() {
    return Discourse.ajax("/admin/logs/screened_urls.json").then(function(screened_urls) {
      return screened_urls.map(function(b) {
        return ScreenedUrl.create(b);
      });
    });
  }
});

export default ScreenedUrl;
