import { unsubscribe as unsubscribePushNotifications } from 'discourse/lib/push-notifications';

export default function logout(siteSettings, keyValueStore) {
  keyValueStore.abandonLocal();
  unsubscribePushNotifications();

  const redirect = siteSettings.logout_redirect;
  if (Ember.isEmpty(redirect)) {
    window.location.pathname = Discourse.getURL('/');
  } else {
    window.location.href = redirect;
  }
}
