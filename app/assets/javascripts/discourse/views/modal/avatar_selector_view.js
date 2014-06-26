/**
  This view handles the avatar selection interface

  @class AvatarSelectorView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.AvatarSelectorView = Discourse.ModalBodyView.extend({
  templateName: 'modal/avatar_selector',
  classNames: ['avatar-selector'],
  title: I18n.t('user.change_avatar.title'),
  saveDisabled: false,
  gravatarRefreshEnabled: Em.computed.not('controller.gravatarRefreshDisabled'),
  hasUploadedAvatar: Em.computed.or('uploadedAvatarTemplate', 'controller.custom_avatar_upload_id'),

  // *HACK* used to select the proper radio button, cause {{action}}
  //  stops the default behavior
  selectedChanged: function() {
    var self = this;
    Em.run.next(function() {
      var value = self.get('controller.selected');
      $('input:radio[name="avatar"]').val([value]);
    });
  }.observes('controller.selected'),

});
