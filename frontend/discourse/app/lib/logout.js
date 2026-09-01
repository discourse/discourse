import { isEmpty } from "@ember/utils";
import { isTesting } from "discourse/lib/environment";
import getURL from "discourse/lib/get-url";
import { helperContext } from "discourse/lib/helpers";
import { clearPushSubscriptionConfirmationForOrigin } from "discourse/lib/push-notifications";

export default function logout({ redirect } = {}) {
  clearPushSubscriptionConfirmationForOrigin();

  if (isTesting()) {
    return;
  }

  const { keyValueStore, siteSettings } = helperContext();

  keyValueStore.abandonLocal();

  window.location = isEmpty(redirect)
    ? getURL(siteSettings.login_required ? "/login" : "/")
    : redirect;
}
