/**
  A modal view for inviting a user to private message

  @class InvitePrivateView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.InvitePrivateView = Discourse.ModalBodyView.extend({
  templateName: 'modal/invite_private',
  title: I18n.t('topic.invite_private.title')
});
