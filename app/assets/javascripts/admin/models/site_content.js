Discourse.SiteContent = Discourse.Model.extend({

  markdown: Em.computed.equal('format', 'markdown'),
  plainText: Em.computed.equal('format', 'plain'),
  html: Em.computed.equal('format', 'html'),
  css: Em.computed.equal('format', 'css'),

  save: function() {
    return Discourse.ajax("/admin/customize/site_contents/" + this.get('content_type'), {
      type: 'PUT',
      data: {content: this.get('content')}
    });
  }

});

Discourse.SiteContent.reopenClass({

  find: function(type) {
    return Discourse.ajax("/admin/customize/site_contents/" + type).then(function (data) {
      return Discourse.SiteContent.create(data.site_content);
    });
  }

});
