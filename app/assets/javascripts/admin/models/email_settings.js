/**
  Our data model for representing the current email settings

  @class EmailSettings
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.EmailSettings = Discourse.Model.extend({});

Discourse.EmailSettings.reopenClass({
  find: function() {
    return Discourse.ajax("/admin/email.json").then(function (settings) {
      return Discourse.EmailSettings.create(settings);
    });
  }
});
