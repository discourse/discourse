/**
  A button to display notification options for categories.

  @class NotificationsButton
  @extends Discourse.DropdownButtonView
  @namespace Discourse
  @module Discourse
**/
Discourse.CategoryNotificationsButton = Discourse.View.extend({
  classNames: ['notification-options'],
  category: Em.computed.alias('controller.model'),
  hidden: Em.computed.alias('category.deleted'),
  templateName: 'category_notification_dropdown',

  watchingClasses: 'fa fa-circle heatmap-high',
  trackingClasses: 'fa fa-circle heatmap-low',
  mutedClasses: 'fa fa-times-circle',
  regularClasses: 'fa fa-circle-o',


  
  init: function() {
    this.display();
    this._super();
  },

  dropDownContent: function() {
    var contents = [];

    _.each([
      ['WATCHING', 'watching', this.watchingClasses],
      ['TRACKING', 'tracking', this.trackingClasses],
      ['REGULAR', 'regular', this.regularClasses],
      ['MUTED', 'muted', this.mutedClasses]
    ], function(pair) {

      contents.push({
          id: Discourse.Category.NotificationLevel[pair[0]],
          title: I18n.t('category.notifications.' + pair[1] + '.title'),
          description: I18n.t('category.notifications.' + pair[1] + '.description'),
          styleClasses: pair[2]
      }
        
        );
    });

    return contents;
  }.property(),

  // displayed Button
  display: function() {
    var icon = "";
    switch (this.get('category').notification_level) {
        case Discourse.Category.NotificationLevel.WATCHING:
          icon = this.watchingClasses;
          break;
        case Discourse.Category.NotificationLevel.TRACKING:
          icon = this.trackingClasses;
          break;
        case Discourse.Category.NotificationLevel.MUTED:
          icon = this.mutedClasses;
          break;
        default:
          icon = this.regularClasses;
          break;
    }
    this.set("icon", icon);
  },

  changeDisplay: function() {
    this.display();
  }.observes('category.notification_level')
});
