import DropdownButtonView from 'discourse/views/dropdown-button';

export default DropdownButtonView.extend({
  classNames: ['notification-options'],
  title: '',
  buttonIncludesText: true,
  activeItem: Em.computed.alias('notificationLevel'),
  notificationLevels: [],
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
    var contents = [],
        prefix = this.get('i18nPrefix'),
        postfix = this.get('i18nPostfix'),
        levels = this.get('notificationLevels');

    _.each(this.get('options'), function(pair) {
      if (postfix === '_pm' && pair[1] === 'regular') { return; }
      contents.push({
        id: levels[pair[0]],
        title: I18n.t(prefix + '.' + pair[1] + postfix + '.title'),
        description: I18n.t(prefix + '.' + pair[1] + postfix + '.description'),
        styleClasses: pair[2]
      });
    });

    return contents;
  }.property(),

  text: function() {
    var self = this,
        prefix = this.get('i18nPrefix'),
        postfix = this.get('i18nPostfix'),
        levels = this.get('notificationLevels');

    var key = (function() {
      switch (this.get('notificationLevel')) {
        case levels.WATCHING: return 'watching';
        case levels.TRACKING: return 'tracking';
        case levels.MUTED: return 'muted';
        default: return 'regular';
      }
    }).call(this);

    var icon = (function() {
      switch (key) {
        case 'watching': return '<i class="' + self.watchingClasses + '"></i>&nbsp;';
        case 'tracking': return '<i class="' + self.trackingClasses +  '"></i>&nbsp;';
        case 'muted': return '<i class="' + self.mutedClasses + '"></i>&nbsp;';
        default: return '<i class="' + self.regularClasses + '"></i>&nbsp;';
      }
    })();
    return icon + ( this.get('buttonIncludesText') ? I18n.t(prefix + '.' + key + postfix + ".title") : '') + "<span class='caret'></span>";
  }.property('notificationLevel'),

  clicked: function(/* id */) {
    // sub-class needs to implement this
  }

});
