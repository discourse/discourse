/**
  Represents a URL that is watched for, and an action may be taken.

  @class ScreenedUrl
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.ScreenedUrl = Discourse.Model.extend({
  actionName: function() {
    return I18n.t("admin.logs.screened_actions." + this.get('action'));
  }.property('action')
});

Discourse.ScreenedUrl.reopenClass({
  findAll: function(filter) {
    return Discourse.ajax("/admin/logs/screened_urls.json").then(function(screened_urls) {
      return screened_urls.map(function(b) {
        return Discourse.ScreenedUrl.create(b);
      });
    });
  }
});
