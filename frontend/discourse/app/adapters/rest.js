import EmberObject from "@ember/object";
import { underscore } from "@ember/string";
import { ajax } from "discourse/lib/ajax";
import { hashString } from "discourse/lib/hash";

const ADMIN_MODELS = [
  "plugin",
  "theme",
  "embeddable-host",
  "web-hook",
  "web-hook-event",
  "flagged-topic",
];

export function Result(payload, responseJson) {
  this.payload = payload;
  this.responseJson = responseJson;
  this.target = null;
}

// We use this to make sure 404s are caught
function rethrow(error) {
  if (error.status === 404) {
    throw new Error("404: " + error.responseText);
  }
  throw error;
}

export default class RestAdapter extends EmberObject {
  primaryKey = "id";
  jsonMode = false;

  storageKey(type, findArgs, options) {
    if (options && options.cacheKey) {
      return options.cacheKey;
    }
    const hashedArgs = Math.abs(hashString(JSON.stringify(findArgs)));
    return `${type}_${hashedArgs}`;
  }

  basePath(store, type) {
    if (ADMIN_MODELS.includes(type.replace("_", "-"))) {
      return "/admin/";
    }
    return "/";
  }

  appendQueryParams(path, findArgs, extension) {
    if (findArgs) {
      if (typeof findArgs === "object") {
        const urlSearchParams = new URLSearchParams();

        for (const [key, value] of Object.entries(findArgs)) {
          if (value) {
            urlSearchParams.set(key, value);
          }
        }

        const queryString = urlSearchParams.toString();

        if (queryString) {
          return `${path}${extension || ""}?${queryString}`;
        }
      } else {
        // It's serializable as a string if not an object
        return `${path}/${encodeURIComponent(findArgs)}${extension || ""}`;
      }
    }
    return path;
  }

  pathFor(store, type, findArgs) {
    let path =
      this.basePath(store, type, findArgs) +
      underscore(store.pluralize(this.apiNameFor(type)));
    return this.appendQueryParams(path, findArgs);
  }

  apiNameFor(type) {
    return type;
  }

  findAll(store, type, findArgs) {
    return ajax(this.pathFor(store, type, findArgs)).catch(rethrow);
  }

  find(store, type, findArgs) {
    return ajax(this.pathFor(store, type, findArgs)).catch(rethrow);
  }

  findStale(store, type, findArgs, options) {
    if (this.cached) {
      return this.cached[this.storageKey(type, findArgs, options)];
    }
  }

  cacheFind(store, type, findArgs, opts, hydrated) {
    this.cached = this.cached || {};
    this.cached[this.storageKey(type, findArgs, opts)] = hydrated;
  }

  getPayload(method, data) {
    let payload = { method, data };

    if (this.jsonMode) {
      payload.contentType = "application/json";
      payload.data = JSON.stringify(data);
    }

    return payload;
  }

  update(store, type, id, attrs) {
    const data = {};
    const typeField = underscore(this.apiNameFor(type));
    data[typeField] = attrs;

    return ajax(
      this.pathFor(store, type, id),
      this.getPayload("PUT", data)
    ).then(function (json) {
      return new Result(json[typeField], json);
    });
  }

  createRecord(store, type, attrs) {
    const data = {};
    const typeField = underscore(this.apiNameFor(type));
    data[typeField] = attrs;
    return ajax(this.pathFor(store, type), this.getPayload("POST", data)).then(
      function (json) {
        return new Result(json[typeField], json);
      }
    );
  }

  destroyRecord(store, type, record) {
    return ajax(this.pathFor(store, type, record.get(this.primaryKey)), {
      type: "DELETE",
    });
  }
}
