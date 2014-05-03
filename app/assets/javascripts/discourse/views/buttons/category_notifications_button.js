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
  
  init: function() {
    this._super();
    this.display();
  },

  dropDownContent: function() {
    var contents = [];

    _.each([
      ['WATCHING', 'watching'],
      ['TRACKING', 'tracking'],
      ['REGULAR', 'regular'],
      ['MUTED', 'muted']
    ], function(pair) {

      if (pair[1] === 'regular') { return; }

      contents.push({
          id: Discourse.Category.NotificationLevel[pair[0]],
          title: I18n.t('category.notifications.' + pair[1] + '.title'),
          description: I18n.t('category.notifications.' + pair[1] + '.description')
      }
        
        );
    });

    return contents;
  }.property(),

  // displayed Button
  display: function() {
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
        case 'watching': return 'fa fa-circle heatmap-high';
        case 'tracking': return 'fa fa-circle heatmap-low';
        case 'muted': return 'fa fa-times-circle';
        default: return '';
      }
    })();
    this.set("text", I18n.t("category.notifications." + key + ".title"));
    this.set("icon", icon);
  },

  changeDisplay: function() {
    this.display();
  }.observes('category.notification_level')
});
