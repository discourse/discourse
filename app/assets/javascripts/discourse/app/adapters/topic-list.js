import PreloadStore from "discourse/lib/preload-store";
import RestAdapter from "discourse/adapters/rest";
import { ajax } from "discourse/lib/ajax";

export function finderFor(filter, params) {
  return function () {
    let url = `/${filter}.json`;

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
  find(store, type, findArgs) {
    const filter = findArgs.filter;
    const params = findArgs.params;

    return PreloadStore.getAndRemove(
      "topic_list",
      finderFor(filter, params)
    ).then(function (result) {
      result.filter = filter;
      result.params = params;
      return result;
    });
  },
});
