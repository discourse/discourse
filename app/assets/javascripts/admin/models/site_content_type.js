Discourse.SiteContentType = Discourse.Model.extend();

Discourse.SiteContentType.reopenClass({
  findAll: function() {
    return Discourse.ajax("/admin/customize/site_content_types").then(function(data) {
      return data.map(function(ct) {
        return Discourse.SiteContentType.create(ct);
      });
    });
  }
});
