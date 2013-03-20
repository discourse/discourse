/**
  Our data model for determining whether there's a new version of Discourse

  @class VersionCheck
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.VersionCheck = Discourse.Model.extend({
  upToDate: function() {
    return this.get('latest_version') === this.get('installed_version');
  }.property('latest_version', 'installed_version'),

  behindByOneVersion: function() {
    return this.get('missing_versions_count') === 1;
  }.property('missing_versions_count'),

  gitLink: function() {
    return "https://github.com/discourse/discourse/tree/" + this.get('installed_sha');
  }.property('installed_sha'),

  shortSha: function() {
    return this.get('installed_sha').substr(0,10);
  }.property('installed_sha')
});

Discourse.VersionCheck.reopenClass({
  find: function() {
    return $.ajax({ url: Discourse.getURL('/admin/version_check'), dataType: 'json' }).then(function(json) {
      return Discourse.VersionCheck.create(json);
    });
  }
});
