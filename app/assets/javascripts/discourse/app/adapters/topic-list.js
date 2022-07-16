import PreloadStore from "discourse/lib/preload-store";
import RestAdapter from "discourse/adapters/rest";
import { ajax } from "discourse/lib/ajax";
import getURL from "discourse-common/lib/get-url";

export function finderFor(filter, params) {
  return function () {
    let url = getURL("/") + filter + ".json";

    if (params) {
      const urlSearchParams = new URLSearchParams();

      for (const [key, value] of Object.entries(params)) {
        if (typeof value !== "undefined") {
          urlSearchParams.set(key, value);
        }
      }

      const queryString = urlSearchParams.toString();

      if (queryString) {
        url += `?${queryString}`;
      }
    }
    return ajax(url);
  };
}

export default RestAdapter.extend({
  async find(store, type, findArgs) {
    const { filter, params } = findArgs;

    const result = await PreloadStore.getAndRemove(
      "topic_list",
      finderFor(filter, params)
    );

    result.filter = filter;
    result.params = params;
    return result;
  },
});
