(function() {

  /**
    Our data model for determining whether there's a new version of Discourse

    @class VersionCheck    
    @extends Discourse.Model
    @namespace Discourse
    @module Discourse
  **/ 
  window.Discourse.VersionCheck = Discourse.Model.extend({});

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
