/**
  Our data model for interacting with custom site content

  @class SiteContent
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.SiteContent = Discourse.Model.extend({

  markdown: Ember.computed.equal('format', 'markdown'),
  plainText: Ember.computed.equal('format', 'plain'),
  html: Ember.computed.equal('format', 'html'),
  css: Ember.computed.equal('format', 'css'),

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