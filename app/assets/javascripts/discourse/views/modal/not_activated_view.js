/**
  A modal view for telling a user they're not activated

  @class NotActivatedView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.NotActivatedView = Discourse.ModalBodyView.extend({
  templateName: 'modal/not_activated',
  title: I18n.t('log_in')
});
