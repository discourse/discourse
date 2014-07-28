/**
  A modal view for deleting a flag.

  @class AdminDeleteFlagView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.AdminDeleteFlagView = Discourse.ModalBodyView.extend({
  templateName: 'admin/templates/modal/admin_delete_flag',
  title: I18n.t('admin.flags.delete_flag_modal_title')
});
