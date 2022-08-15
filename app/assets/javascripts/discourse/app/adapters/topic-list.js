import PreloadStore from "discourse/lib/preload-store";
import RestAdapter from "discourse/adapters/rest";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse-common/lib/get-url";

export function finderFor(filter, params) {
  return function () {
    let url = new URL(getURL("/") + filter + ".json");

    if (params) {
      for (const [key, value] of Object.entries(params)) {
        if (typeof value !== "undefined") {
          url.searchParams.set(key, value);
        }
      }
    }
    return ajax(url.toString());
  };
}

export default RestAdapter.extend({
  find(store, type, findArgs) {
    const filter = findArgs.filter;
    const params = findArgs.params;

    return PreloadStore.getAndRemove(
      "topic_list_" + filter,
      finderFor(filter, params)
    ).then(function (result) {
      result.filter = filter;
      result.params = params;
      return result;
    });
  },
});
