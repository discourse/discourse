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

  watchingClasses: 'fa fa-exclamation-circle watching',
  trackingClasses: 'fa fa-circle tracking',
  mutedClasses: 'fa fa-times-circle muted',

  dropDownContent: function() {
    var contents = [], postfix = '';

    if (this.get('isPrivateMessage')) { postfix = '_pm'; }

    _.each([
      ['WATCHING', 'watching', this.watchingClasses],
      ['TRACKING', 'tracking', this.trackingClasses],
      ['REGULAR', 'regular', 'tracking'],
      ['MUTED', 'muted', this.mutedClasses]
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
    var self = this;

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
        case 'watching': return '<i class="' + self.watchingClasses + '"></i>&nbsp;';
        case 'tracking': return '<i class="' + self.trackingClasses +  '"></i>&nbsp;';
        case 'muted': return '<i class="' + self.mutedClasses + '"></i>&nbsp;';
        default: return '';
      }
    })();
    return icon + (I18n.t("topic.notifications." + key + ".title")) + "<span class='caret'></span>";
  }.property('topic.details.notification_level'),

  clicked: function(id) {
    return this.get('topic.details').updateNotifications(id);
  }

});

