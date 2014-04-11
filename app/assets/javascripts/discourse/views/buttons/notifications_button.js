/**
  A button to display notification options.

  @class NotificationsButton
  @extends Discourse.DropdownButtonView
  @namespace Discourse
  @module Discourse
**/
Discourse.NotificationsButton = Discourse.DropdownButtonView.extend({
  classNames: ['notification-options'],
  title: '',
  longDescriptionBinding: 'topic.details.notificationReasonText',
  topic: Em.computed.alias('controller.model'),
  hidden: Em.computed.alias('topic.deleted'),
  isPrivateMessage: Em.computed.alias('topic.isPrivateMessage'),
  activeItem: Em.computed.alias('topic.details.notification_level'),

  dropDownContent: function() {
    var contents = [], postfix = '';

    if (this.get('isPrivateMessage')) { postfix = '_pm'; }

    _.each([
      ['WATCHING', 'watching', 'fa fa-circle heatmap-high'],
      ['TRACKING', 'tracking', 'fa fa-circle heatmap-low'],
      ['REGULAR', 'regular', ''],
      ['MUTED', 'muted', 'fa fa-times-circle']
    ], function(pair) {

      if (postfix === '_pm' && pair[1] === 'regular') { return; }

      contents.push([
          Discourse.Topic.NotificationLevel[pair[0]],
          'topic.notifications.' + pair[1] + postfix,
          pair[2]
        ]);
    });

    return contents;
  }.property(),

  text: function() {
    var key = (function() {
      switch (this.get('topic.details.notification_level')) {
        case Discourse.Topic.NotificationLevel.WATCHING: return 'watching';
        case Discourse.Topic.NotificationLevel.TRACKING: return 'tracking';
        case Discourse.Topic.NotificationLevel.MUTED: return 'muted';
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

