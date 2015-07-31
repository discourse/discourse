export default Ember.Component.extend({
  classNames: ['controls'],

  notificationsPermission: function() {
    if (this.get('isNotSupported')) return '';

    return Notification.permission;
  }.property(),

  notificationsDisabled: function(_, value) {
    if (arguments.length > 1) {
      localStorage.setItem('notifications-disabled', value);
    }
    return localStorage.getItem('notifications-disabled');
  }.property(),


  isNotSupported: function() {
    return !window['Notification'];
  }.property(),

  isDefaultPermission: function() {
    if (this.get('isNotSupported')) return false;

    return Notification.permission === "default";
  }.property('isNotSupported', 'notificationsPermission'),

  isDeniedPermission: function() {
    if (this.get('isNotSupported')) return false;

    return Notification.permission === "denied";
  }.property('isNotSupported', 'notificationsPermission'),

  isGrantedPermission: function() {
    if (this.get('isNotSupported')) return false;

    return Notification.permission === "granted";
  }.property('isNotSupported', 'notificationsPermission'),

  isEnabled: function() {
    if (!this.get('isGrantedPermission')) return false;

    return !this.get('notificationsDisabled');
  }.property('isGrantedPermission', 'notificationsDisabled'),

  actions: {
    requestPermission() {
      const self = this;
      Notification.requestPermission(function() {
        self.propertyDidChange('notificationsPermission');
      });
    },
    recheckPermission() {
      this.propertyDidChange('notificationsPermission');
    },
    turnoff() {
      this.set('notificationsDisabled', 'disabled');
      this.propertyDidChange('notificationsPermission');
    },
    turnon() {
      this.set('notificationsDisabled', '');
      this.propertyDidChange('notificationsPermission');
    }
  }
});
