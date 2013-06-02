/**
  A modal view for telling a user they're not activated

  @class NotActivatedView
  @extends Discourse.ModalBodyView
  @namespace Discourse
  @module Discourse
**/
Discourse.NotActivatedView = Discourse.ModalBodyView.extend({
  templateName: 'modal/not_activated',
  title: Em.String.i18n('log_in')
});
