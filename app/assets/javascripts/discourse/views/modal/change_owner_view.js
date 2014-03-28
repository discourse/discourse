/**
 A modal view for handling changing the owner of various posts

 @class ChangeOwnerView
 @extends Discourse.ModalBodyView
 @namespace Discourse
 @module Discourse
 **/
Discourse.ChangeOwnerView = Discourse.ModalBodyView.extend({
  templateName: 'modal/change_owner',
  title: I18n.t('topic.change_owner.title')
});
