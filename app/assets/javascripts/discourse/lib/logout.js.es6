export default function logout(siteSettings, keyValueStore) {
  keyValueStore.abandonLocal();

  const redirect = siteSettings.logout_redirect;
  if (Ember.isEmpty(redirect)) {
    window.location.pathname = Discourse.getURL('/');
  } else {
    window.location.href = redirect;
  }
}
