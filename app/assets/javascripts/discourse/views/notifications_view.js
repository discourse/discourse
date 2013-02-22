/**
  This view handles rendering of a user's notifications

  @class NotificationsView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.NotificationsView = Discourse.View.extend({
  classNameBindings: ['content.read', ':notifications'],
  templateName: 'notifications'
});


