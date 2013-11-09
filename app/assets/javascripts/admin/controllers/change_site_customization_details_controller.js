/**
  The modal for viewing the details of a staff action log record
  for when a site customization is created or changed.

  @class ChangeSiteCustomizationDetailsController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.ChangeSiteCustomizationDetailsController = Discourse.ObjectController.extend(Discourse.ModalFunctionality, {
  previousSelected: Ember.computed.equal('selectedTab', 'previous'),
  newSelected:      Ember.computed.equal('selectedTab', 'new'),

  onShow: function() {
    this.selectNew();
  },

  selectNew: function() {
    this.set('selectedTab', 'new');
  },

  selectPrevious: function() {
    this.set('selectedTab', 'previous');
  }
});
