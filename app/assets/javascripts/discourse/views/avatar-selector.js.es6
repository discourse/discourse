import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'modal/avatar_selector',
  classNames: ['avatar-selector'],
  title: I18n.t('user.change_avatar.title'),
  saveDisabled: false,
  gravatarRefreshEnabled: Em.computed.not('controller.gravatarRefreshDisabled'),
  hasUploadedAvatar: Em.computed.or('uploadedAvatarTemplate', 'controller.custom_avatar_upload_id'),

  // *HACK* used to select the proper radio button, cause {{action}}
  //  stops the default behavior
  selectedChanged: function() {
    Em.run.next(() => $('input:radio[name="avatar"]').val([this.get('controller.selected')]) );
  }.observes('controller.selected')
});
