import getURL from "discourse-common/lib/get-url";
import { isEmpty } from "@ember/utils";
import { findAll } from "discourse/models/login-method";
import { helperContext } from "discourse-common/lib/helpers";

export default function logout() {
  const ctx = helperContext();
  let siteSettings = ctx.siteSettings;
  let keyValueStore = ctx.keyValueStore;
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
    window.location.href = getURL("/login");
    return;
  }

  window.location.href = getURL("/");
}
