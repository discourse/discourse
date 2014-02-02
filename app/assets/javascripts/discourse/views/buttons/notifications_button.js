/**
  A button to display notification options.

  @class NotificationsButton
  @extends Discourse.DropdownButtonView
  @namespace Discourse
  @module Discourse
**/
Discourse.NotificationsButton = Discourse.DropdownButtonView.extend({
  classNames: ['notification-options'],
  title: I18n.t('topic.notifications.title'),
  longDescriptionBinding: 'topic.details.notificationReasonText',
  topic: Em.computed.alias('controller.model'),
  hidden: Em.computed.alias('topic.deleted'),
  isPrivateMessage: Em.computed.alias('topic.isPrivateMessage'),

  dropDownContent: function() {
    var contents = [], postfix = '';

    if (this.get('isPrivateMessage')) { postfix = '_pm'; }

    _.each([
      ['WATCHING', 'watching'],
      ['TRACKING', 'tracking'],
      ['REGULAR', 'regular'],
      ['MUTE', 'muted']
    ], function(pair) {

      if (postfix === '_pm' && pair[1] === 'regular') { return; }

      contents.push([
          Discourse.Topic.NotificationLevel[pair[0]],
          'topic.notifications.' + pair[1] + postfix
        ]);
    });

    return contents;
  }.property(),

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
        case 'watching': return '<i class="fa fa-circle heatmap-high"></i>&nbsp;';
        case 'tracking': return '<i class="fa fa-circle heatmap-low"></i>&nbsp;';
        case 'muted': return '<i class="fa fa-times-circle"></i>&nbsp;';
        default: return '';
      }
    })();
    return icon + (I18n.t("topic.notifications." + key + ".title")) + "<span class='caret'></span>";
  }.property('topic.details.notification_level'),

  clicked: function(id) {
    return this.get('topic.details').updateNotifications(id);
  }

});

