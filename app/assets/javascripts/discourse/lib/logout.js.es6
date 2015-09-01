export default function logout(siteSettings) {
  Discourse.KeyValueStore.abandonLocal();

  const redirect = siteSettings.logout_redirect;
  if (Ember.isEmpty(redirect)) {
    window.location.pathname = Discourse.getURL('/');
  } else {
    window.location.href = redirect;
  }
}
