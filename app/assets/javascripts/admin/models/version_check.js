(function() {

  /**
    Our data model for determining whether there's a new version of Discourse

    @class VersionCheck
    @extends Discourse.Model
    @namespace Discourse
    @module Discourse
  **/
  window.Discourse.VersionCheck = Discourse.Model.extend({
    upToDate: function() {
      return this.get('latest_version') === this.get('installed_version');
    }.property('latest_version', 'installed_version'),

    gitLink: function() {
      return "https://github.com/discourse/discourse/tree/" + this.get('installed_sha');
    }.property('installed_sha'),

    shortSha: function() {
      return this.get('installed_sha').substr(0,10);
    }.property('installed_sha')
  });

  Discourse.VersionCheck.reopenClass({
    find: function() {
      var promise = new RSVP.Promise();
      jQuery.ajax({
        url: '/admin/version_check',
        dataType: 'json',
        success: function(json) {
          promise.resolve(Discourse.VersionCheck.create(json));
        }
      });
      return promise;
    }
  });

}).call(this);
