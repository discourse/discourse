/**
  A button to display notification options for categories.

  @class NotificationsButton
  @extends Discourse.DropdownButtonView
  @namespace Discourse
  @module Discourse
**/
Discourse.CategoryNotificationsButton = Discourse.CategoryNotificationDropdownButtonView.extend({
  classNames: ['notification-options'],
  //title: I18n.t('category.notifications.title'),
  //longDescriptionBinding: 'topic.details.notificationReasonText',
  //topic: Em.computed.alias('controller.model'),
  category: Em.computed.alias('controller.model'),
  hidden: Em.computed.alias('topic.deleted'),

  dropDownContent: function() {
    var contents = [];

    _.each([
      ['WATCHING', 'watching'],
      ['TRACKING', 'tracking'],
      ['REGULAR', 'regular'],
      ['MUTED', 'muted']
    ], function(pair) {

      if (pair[1] === 'regular') { return; }

      contents.push([
          Discourse.Category.NotificationLevel[pair[0]],
          'category.notifications.' + pair[1]
        ]);
    });

    return contents;
  }.property(),

  // displayed Button
  text: function() {
    var key = (function() {
      switch (this.get('category.notification_level')) {
        case Discourse.Category.NotificationLevel.WATCHING: return 'watching';
        case Discourse.Category.NotificationLevel.TRACKING: return 'tracking';
        case Discourse.Category.NotificationLevel.MUTED: return 'muted';
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
    return icon + (I18n.t("category.notifications." + key + ".title")) + "<span class='caret'></span>";
  }.property('category.notification_level'),

  clicked: function(id) {
    return this.get('category').setNotification(id);
  }

});

