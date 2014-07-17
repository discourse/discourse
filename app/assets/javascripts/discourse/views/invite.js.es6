export default Discourse.ModalBodyView.extend({
  templateName: 'modal/invite',
  title: function() {
    if (this.get('controller.invitingToTopic')) {
      return I18n.t('topic.invite_reply.title');
    } else {
      return I18n.t('user.invited.create');
    }
  }.property('controller.invitingToTopic')
});
