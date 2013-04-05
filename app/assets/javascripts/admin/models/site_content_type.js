/**
  Our data model that represents types of editing site content

  @class SiteContentType
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.SiteContentType = Discourse.Model.extend({});

Discourse.SiteContentType.reopenClass({
  findAll: function() {
    var contentTypes = Em.A();
    Discourse.ajax(Discourse.getURL("/admin/site_content_types")).then(function(data) {
      data.forEach(function (ct) {
        contentTypes.pushObject(Discourse.SiteContentType.create(ct));
      });
    });
    return contentTypes;
  }
});
