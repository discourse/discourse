/**
  The modal for viewing the details of a staff action log record
  for when a site customization is deleted.

  @class DeleteSiteCustomizationDetailsController
  @extends Discourse.Controller
  @namespace Discourse
  @uses Discourse.ModalFunctionality
  @module Discourse
**/
Discourse.DeleteSiteCustomizationDetailsController = Discourse.ChangeSiteCustomizationDetailsController.extend({
  onShow: function() {
    this.selectPrevious();
  }
});
