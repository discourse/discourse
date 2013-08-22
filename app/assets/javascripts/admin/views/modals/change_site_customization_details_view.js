/**
  A modal view for details of a staff action log record in a modal
  for when a site customization is created or changed.

  @class ChangeSiteCustomizationDetailsView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.ChangeSiteCustomizationDetailsView = Discourse.ModalBodyView.extend({
  templateName: 'admin/templates/logs/site_customization_change_modal',
  title: I18n.t('admin.logs.staff_actions.modal_title')
});
