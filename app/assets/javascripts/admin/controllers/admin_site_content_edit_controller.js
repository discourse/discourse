/**
  This controller is used for editing site content

  @class AdminSiteContentEditController
  @extends Ember.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminSiteContentEditController = Discourse.Controller.extend({

  saveDisabled: function() {
    if (this.get('saving')) { return true; }
    if ((!this.get('content.allow_blank')) && this.blank('content.content')) { return true; }
    return false;
  }.property('saving', 'content.content'),

  actions: {
    saveChanges: function() {
      var self = this;
      self.setProperties({saving: true, saved: false});
      self.get('content').save().then(function () {
        self.setProperties({saving: false, saved: true});
      });
    }
  }
});

Discourse.AdminSiteContentsController = Ember.ArrayController.extend({});