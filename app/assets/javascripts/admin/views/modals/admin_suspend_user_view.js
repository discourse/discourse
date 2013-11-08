/**
  A modal view for suspending a user.

  @class AdminSuspendUserView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminSuspendUserView = Discourse.ModalBodyView.extend({
  templateName: 'admin/templates/modal/admin_suspend_user',
  title: I18n.t('admin.user.suspend_modal_title')
});
