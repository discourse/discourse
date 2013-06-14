/**
  This controller is used for editing site content

  @class AdminSiteContentEditController
  @extends Ember.ObjectController
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminSiteContentEditController = Discourse.Controller.extend({

  saveDisabled: function() {
    if (this.get('saving')) return true;
    if (this.blank('content.content')) return true;
    return false;
  }.property('saving', 'content.content'),

  saveChanges: function() {
    var controller = this;
    controller.setProperties({saving: true, saved: false});
    this.get('content').save().then(function () {
      controller.setProperties({saving: false, saved: true});
    });
  }

});