import getURL from "discourse-common/lib/get-url";
import { helperContext } from "discourse-common/lib/helpers";
import { isEmpty } from "@ember/utils";
import { isTesting } from "discourse-common/config/environment";

export default function logout({ redirect } = {}) {
  if (isTesting()) {
    return;
  }

  const ctx = helperContext();
  let keyValueStore = ctx.keyValueStore;
  keyValueStore.abandonLocal();

  if (!isEmpty(redirect)) {
    window.location.href = redirect;
    return;
  }
  const url = ctx.siteSettings.login_required ? "/login" : "/";
  window.location.href = getURL(url);
}
