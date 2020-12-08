import getURL from "discourse-common/lib/get-url";
import { helperContext } from "discourse-common/lib/helpers";
import { isEmpty } from "@ember/utils";

export default function logout({ redirect } = {}) {
  const ctx = helperContext();
  let keyValueStore = ctx.keyValueStore;
  keyValueStore.abandonLocal();

  if (!isEmpty(redirect)) {
    window.location.href = redirect;
    return;
  }

  window.location.href = getURL("/");
}
