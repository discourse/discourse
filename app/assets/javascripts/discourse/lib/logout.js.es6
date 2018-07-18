export default function logout(siteSettings, keyValueStore) {
  if (!siteSettings || !keyValueStore) {
    const container = Discourse.__container__;
    siteSettings = siteSettings || container.lookup("site-settings:main");
    keyValueStore = keyValueStore || container.lookup("key-value-store:main");
  }

  keyValueStore.abandonLocal();

  const redirect = siteSettings.logout_redirect;
  if (Ember.isEmpty(redirect)) {
    window.location.pathname = Discourse.getURL("/");
  } else {
    window.location.href = redirect;
  }
}
