/**
  A button for favoriting a topic

  @class NotificationsButton
  @extends Discourse.DropdownButtonView
  @namespace Discourse
  @module Discourse
**/
Discourse.NotificationsButton = Discourse.DropdownButtonView.extend({
  title: I18n.t('topic.notifications.title'),
  longDescriptionBinding: 'topic.details.notificationReasonText',
  topic: Em.computed.alias('controller.model'),
  hidden: Em.computed.alias('topic.deleted'),

  dropDownContent: [
    [Discourse.Topic.NotificationLevel.WATCHING, 'topic.notifications.watching'],
    [Discourse.Topic.NotificationLevel.TRACKING, 'topic.notifications.tracking'],
    [Discourse.Topic.NotificationLevel.REGULAR, 'topic.notifications.regular'],
    [Discourse.Topic.NotificationLevel.MUTE, 'topic.notifications.muted']
  ],

  text: function() {
    var key = (function() {
      switch (this.get('topic.details.notification_level')) {
        case Discourse.Topic.NotificationLevel.WATCHING: return 'watching';
        case Discourse.Topic.NotificationLevel.TRACKING: return 'tracking';
        case Discourse.Topic.NotificationLevel.MUTE: return 'muted';
        default: return 'regular';
      }
    }).call(this);

    var icon = (function() {
      switch (key) {
        case 'watching': return '<i class="icon-circle heatmap-high"></i>&nbsp;';
        case 'tracking': return '<i class="icon-circle heatmap-low"></i>&nbsp;';
        case 'muted': return '<i class="icon-remove-sign"></i>&nbsp;';
        default: return '';
      }
    })();
    return icon + (I18n.t("topic.notifications." + key + ".title")) + "<span class='caret'></span>";
  }.property('topic.details.notification_level'),

  clicked: function(id) {
    return this.get('topic.details').updateNotifications(id);
  }

});

