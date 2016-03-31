import computed from 'ember-addons/ember-computed-decorators';
import KeyValueStore from 'discourse/lib/key-value-store';

const keyValueStore = new KeyValueStore("discourse_desktop_notifications_");

export default Ember.Component.extend({
  classNames: ['controls'],

  @computed("isNotSupported")
  notificationsPermission(isNotSupported) {
    return isNotSupported ? "" : Notification.permission;
  },

  @computed
  notificationsDisabled: {
    set(value) {
      keyValueStore.setItem('notifications-disabled', value);
      return keyValueStore.getItem('notifications-disabled');
    },
    get() {
      return keyValueStore.getItem('notifications-disabled');
    }
  },

  @computed
  isNotSupported() {
    return typeof window.Notification === "undefined";
  },

  @computed("isNotSupported", "notificationsPermission")
  isDefaultPermission(isNotSupported, notificationsPermission) {
    return isNotSupported ? false : notificationsPermission === "default";
  },

  @computed("isNotSupported", "notificationsPermission")
  isDeniedPermission(isNotSupported, notificationsPermission) {
    return isNotSupported ? false : notificationsPermission === "denied";
  },

  @computed("isNotSupported", "notificationsPermission")
  isGrantedPermission(isNotSupported, notificationsPermission) {
    return isNotSupported ? false : notificationsPermission === "granted";
  },

  @computed("isGrantedPermission", "notificationsDisabled")
  isEnabled(isGrantedPermission, notificationsDisabled) {
    return isGrantedPermission ? !notificationsDisabled : false;
  },

  actions: {
    requestPermission() {
      Notification.requestPermission(() => this.propertyDidChange('notificationsPermission'));
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
