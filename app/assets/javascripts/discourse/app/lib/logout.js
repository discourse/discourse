import { isEmpty } from "@ember/utils";
import { findAll } from "discourse/models/login-method";

export default function logout(siteSettings, keyValueStore) {
  if (!siteSettings || !keyValueStore) {
    const container = Discourse.__container__;
    siteSettings = siteSettings || container.lookup("site-settings:main");
    keyValueStore = keyValueStore || container.lookup("key-value-store:main");
  }

  keyValueStore.abandonLocal();

  const redirect = siteSettings.logout_redirect;
  if (!isEmpty(redirect)) {
    window.location.href = redirect;
    return;
  }

  const sso = siteSettings.enable_sso;
  const oneAuthenticator =
    !siteSettings.enable_local_logins && findAll().length === 1;

  if (siteSettings.login_required && (sso || oneAuthenticator)) {
    // In this situation visiting most URLs will start the auth process again
    // Go to the `/login` page to avoid an immediate redirect
    window.location.href = Discourse.getURL("/login");
    return;
  }

  window.location.href = Discourse.getURL("/");
}
