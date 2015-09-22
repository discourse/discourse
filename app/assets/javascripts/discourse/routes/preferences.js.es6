import RestrictedUserRoute from "discourse/routes/restricted-user";
import showModal from 'discourse/lib/show-modal';
import { popupAjaxError } from 'discourse/lib/ajax-error';

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
      const props = this.modelFor('user').getProperties(
              'id',
              'email',
              'username',
              'avatar_template',
              'system_avatar_template',
              'gravatar_avatar_template',
              'custom_avatar_template',
              'system_avatar_upload_id',
              'gravatar_avatar_upload_id',
              'custom_avatar_upload_id'
            );

      switch (props.avatar_template) {
        case props.system_avatar_template:
          props.selected = "system";
          break;
        case props.gravatar_avatar_template:
          props.selected = "gravatar";
          break;
        default:
          props.selected = "uploaded";
      }

      this.controllerFor('avatar-selector').setProperties(props);
    },

    saveAvatarSelection() {
      const user = this.modelFor('user'),
            controller = this.controllerFor('avatar-selector'),
            selectedUploadId = controller.get("selectedUploadId"),
            selectedAvatarTemplate = controller.get("selectedAvatarTemplate"),
            type = controller.get("selected");

      user.pickAvatar(selectedUploadId, type, selectedAvatarTemplate)
          .then(() => {
            user.setProperties(controller.getProperties(
              'system_avatar_template',
              'gravatar_avatar_template',
              'custom_avatar_template'
            ));
            bootbox.alert(I18n.t("user.change_avatar.cache_notice"));
          }).catch(popupAjaxError);

      // saves the data back
      controller.send('closeModal');
    },

  }
});
