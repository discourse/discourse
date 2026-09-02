import RestAdapter from "discourse/adapters/rest";
import { ajax } from "discourse/lib/ajax";
import { serverFilterForMode } from "discourse/lib/filter-mode";
import PreloadStore from "discourse/lib/preload-store";
import Topic from "discourse/models/topic";

export default class TopicListAdapter extends RestAdapter {
  async find(store, type, { filter, params }) {
    const result =
      (await this.#preloadedList(filter)) ??
      (await ajax(this.#url(filter, params)));

    result.filter = filter;
    result.params = params;
    return result;
  }

  // The server preloads whichever list it rendered under a single key, so it is
  // only usable when it is the list we asked for. Falls through when either side
  // cannot be identified.
  async #preloadedList(filter) {
    const preloaded = await PreloadStore.getAndRemove("topic_list");
    if (!preloaded) {
      return;
    }

    const served = preloaded.topic_list?.filter;
    const requested = serverFilterForMode(filter);

    if (served && requested && served !== requested) {
      return;
    }

    return preloaded;
  }

  #url(filter, params) {
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

    return url;
  }

  async applyTransformations(results) {
    for (const topicList of results) {
      await Topic.applyTransformations(topicList.topics);
    }
  }
}
