import getURL from "discourse-common/lib/get-url";
import { helperContext } from "discourse-common/lib/helpers";
import { isEmpty } from "@ember/utils";

class Zomg {
  logout({ redirect } = {}) {
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
}

export let __ZOMG__ = new Zomg();

export default function logout(...args) {
  return __ZOMG__.logout(...args);
}
