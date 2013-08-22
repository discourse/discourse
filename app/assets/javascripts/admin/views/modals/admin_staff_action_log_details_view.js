/**
  A modal view for details of a staff action log record in a modal.

  @class AdminStaffActionLogDetailsView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminStaffActionLogDetailsView = Discourse.ModalBodyView.extend({
  templateName: 'admin/templates/logs/details_modal',
  title: I18n.t('admin.logs.staff_actions.modal_title')
});
