/**
  A modal view for details of a staff action log record in a modal
  for when a site customization is deleted.

  @class DeleteSiteCustomizationDetailsView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.DeleteSiteCustomizationDetailsView = Discourse.ModalBodyView.extend({
  templateName: 'admin/templates/logs/site_customization_change_modal',
  title: I18n.t('admin.logs.staff_actions.modal_title')
});
