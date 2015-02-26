import DropdownButton from 'discourse/components/dropdown-button';
import NotificationLevels from 'discourse/lib/notification-levels';

const NotificationsButton = DropdownButton.extend({
  classNames: ['notification-options'],
  title: '',
  buttonIncludesText: true,
  activeItem: Em.computed.alias('notificationLevel'),
  i18nPrefix: '',
  i18nPostfix: '',
  watchingClasses: 'fa fa-exclamation-circle watching',
  trackingClasses: 'fa fa-circle tracking',
  mutedClasses: 'fa fa-times-circle muted',
  regularClasses: 'fa fa-circle-o regular',

  options: function() {
    return [['WATCHING', 'watching', this.watchingClasses],
            ['TRACKING', 'tracking', this.trackingClasses],
            ['REGULAR',  'regular',  this.regularClasses],
            ['MUTED',    'muted',    this.mutedClasses]];
  }.property(),

  dropDownContent: function() {
    const contents = [],
          prefix = this.get('i18nPrefix'),
          postfix = this.get('i18nPostfix');

    _.each(this.get('options'), function(pair) {
      if (postfix === '_pm' && pair[1] === 'regular') { return; }
      contents.push({
        id: NotificationLevels[pair[0]],
        title: I18n.t(prefix + '.' + pair[1] + postfix + '.title'),
        description: I18n.t(prefix + '.' + pair[1] + postfix + '.description'),
        styleClasses: pair[2]
      });
    });

    return contents;
  }.property(),

  text: function() {
    const self = this,
          prefix = this.get('i18nPrefix'),
          postfix = this.get('i18nPostfix');

    const key = (function() {
      switch (this.get('notificationLevel')) {
        case NotificationLevels.WATCHING: return 'watching';
        case NotificationLevels.TRACKING: return 'tracking';
        case NotificationLevels.MUTED: return 'muted';
        default: return 'regular';
      }
    }).call(this);

    const icon = (function() {
      switch (key) {
        case 'watching': return '<i class="' + self.watchingClasses + '"></i>&nbsp;';
        case 'tracking': return '<i class="' + self.trackingClasses +  '"></i>&nbsp;';
        case 'muted': return '<i class="' + self.mutedClasses + '"></i>&nbsp;';
        default: return '<i class="' + self.regularClasses + '"></i>&nbsp;';
      }
    })();
    return icon + ( this.get('buttonIncludesText') ? I18n.t(prefix + '.' + key + postfix + ".title") : '') + "<span class='caret'></span>";
  }.property('notificationLevel'),

  clicked(/* id */) {
    // sub-class needs to implement this
  }

});

export default NotificationsButton;
export { NotificationLevels };
