import PreloadStore from "discourse/lib/preload-store";
import RestAdapter from "discourse/adapters/rest";
import { ajax } from "discourse/lib/ajax";

export default RestAdapter.extend({
  find(store, type, { filter, params }) {
    return PreloadStore.getAndRemove("topic_list", () => {
      let url = `/${filter}.json`;

      if (params) {
        const urlSearchParams = new URLSearchParams();

        for (const [key, value] of Object.entries(params)) {
          if (typeof value === "undefined") {
            continue;
          }

          if (Array.isArray(value)) {
            for (const arrayValue of value) {
              urlSearchParams.append(`${key}[]`, arrayValue);
            }
          } else {
            urlSearchParams.set(key, value);
          }
        }

        const queryString = urlSearchParams.toString();

        if (queryString) {
          url += `?${queryString}`;
        }
      }

      return ajax(url);
    }).then((result) => {
      result.filter = filter;
      result.params = params;
      return result;
    });
  },
});
