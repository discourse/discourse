import ModalBodyView from "discourse/views/modal-body";

export default ModalBodyView.extend({
  templateName: 'modal/invite',

  title: function() {
    return this.get('controller.invitingToTopic') ?
           I18n.t('topic.invite_reply.title') :
           I18n.t('user.invited.create');
  }.property('controller.invitingToTopic')

});
