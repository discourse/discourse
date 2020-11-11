import getURL from "discourse-common/lib/get-url";
import { isEmpty } from "@ember/utils";
import { helperContext } from "discourse-common/lib/helpers";

export default function logout({ redirect_url } = {}) {
  const ctx = helperContext();
  let keyValueStore = ctx.keyValueStore;
  keyValueStore.abandonLocal();

  if (!isEmpty(redirect_url)) {
    window.location.href = redirect_url;
    return;
  }

  window.location.href = getURL("/");
}
