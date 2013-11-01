/**
  A modal view for banning a user.

  @class AdminBanUserView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminBanUserView = Discourse.ModalBodyView.extend({
  templateName: 'admin/templates/modal/admin_ban_user',
  title: I18n.t('admin.user.ban_modal_title')
});
