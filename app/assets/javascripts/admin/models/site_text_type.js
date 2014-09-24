Discourse.SiteTextType = Discourse.Model.extend();

Discourse.SiteTextType.reopenClass({
  findAll: function() {
    return Discourse.ajax("/admin/customize/site_text_types").then(function(data) {
      return data.map(function(ct) {
        return Discourse.SiteTextType.create(ct);
      });
    });
  }
});
