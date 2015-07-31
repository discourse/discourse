import RestrictedUserRoute from "discourse/routes/restricted-user";
import showModal from 'discourse/lib/show-modal';

export default RestrictedUserRoute.extend({
  model() {
    return this.modelFor('user');
  },

  setupController(controller, user) {
    controller.setProperties({
      model: user,
      newNameInput: user.get('name')
    });
  },

  actions: {
    showAvatarSelector() {
      showModal('avatar-selector');

      // all the properties needed for displaying the avatar selector modal
      const controller = this.controllerFor('avatar-selector'),
            props = this.modelFor('user').getProperties(
              'id',
              'email',
              'username',
              'uploaded_avatar_id',
              'system_avatar_upload_id',
              'gravatar_avatar_upload_id',
              'custom_avatar_upload_id'
            );

      switch (props.uploaded_avatar_id) {
        case props.system_avatar_upload_id:
          props.selected = "system";
          break;
        case props.gravatar_avatar_upload_id:
          props.selected = "gravatar";
          break;
        default:
          props.selected = "uploaded";
      }

      controller.setProperties(props);
    },

    saveAvatarSelection() {
      const user = this.modelFor('user'),
            avatarSelector = this.controllerFor('avatar-selector');

      // sends the information to the server if it has changed
      if (avatarSelector.get('selectedUploadId') !== user.get('uploaded_avatar_id')) {
        user.pickAvatar(avatarSelector.get('selectedUploadId'))
            .then(() => {
              user.setProperties(avatarSelector.getProperties(
                'system_avatar_upload_id',
                'gravatar_avatar_upload_id',
                'custom_avatar_upload_id'
              ));
              bootbox.alert(I18n.t("user.change_avatar.cache_notice"));
            });
      }

      // saves the data back
      avatarSelector.send('closeModal');
    },

  }
});
