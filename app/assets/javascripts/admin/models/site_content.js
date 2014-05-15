/**
  Our data model for interacting with custom site content

  @class SiteContent
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.SiteContent = Discourse.Model.extend({

  markdown: Em.computed.equal('format', 'markdown'),
  plainText: Em.computed.equal('format', 'plain'),
  html: Em.computed.equal('format', 'html'),
  css: Em.computed.equal('format', 'css'),

  /**
    Save the content

    @method save
    @return {jqXHR} a jQuery Promise object
  **/
  save: function() {
    return Discourse.ajax("/admin/site_contents/" + this.get('content_type'), {
      type: 'PUT',
      data: {content: this.get('content')}
    });
  }

});

Discourse.SiteContent.reopenClass({

  find: function(type) {
    return Discourse.ajax("/admin/site_contents/" + type).then(function (data) {
      return Discourse.SiteContent.create(data.site_content);
    });
  }

});
