import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { hashString } from "discourse/lib/hash";

const ADMIN_MODELS = [
  "plugin",
  "theme",
  "embeddable-host",
  "web-hook",
  "web-hook-event",
  "flagged-topic"
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

export default EmberObject.extend({
  storageKey(type, findArgs, options) {
    if (options && options.cacheKey) {
      return options.cacheKey;
    }
    const hashedArgs = Math.abs(hashString(JSON.stringify(findArgs)));
    return `${type}_${hashedArgs}`;
  },

  basePath(store, type) {
    if (ADMIN_MODELS.indexOf(type.replace("_", "-")) !== -1) {
      return "/admin/";
    }
    return "/";
  },

  appendQueryParams(path, findArgs, extension) {
    if (findArgs) {
      if (typeof findArgs === "object") {
        const queryString = Object.keys(findArgs)
          .reject(k => !findArgs[k])
          .map(k => k + "=" + encodeURIComponent(findArgs[k]));

        if (queryString.length) {
          return `${path}${extension ? extension : ""}?${queryString.join(
            "&"
          )}`;
        }
      } else {
        // It's serializable as a string if not an object
        return `${path}/${encodeURIComponent(findArgs)}${
          extension ? extension : ""
        }`;
      }
    }
    return path;
  },

  pathFor(store, type, findArgs) {
    let path =
      this.basePath(store, type, findArgs) +
      Ember.String.underscore(store.pluralize(type));
    return this.appendQueryParams(path, findArgs);
  },

  findAll(store, type, findArgs) {
    return ajax(this.pathFor(store, type, findArgs)).catch(rethrow);
  },

  find(store, type, findArgs) {
    return ajax(this.pathFor(store, type, findArgs)).catch(rethrow);
  },

  findStale(store, type, findArgs, options) {
    if (this.cached) {
      return this.cached[this.storageKey(type, findArgs, options)];
    }
  },

  cacheFind(store, type, findArgs, opts, hydrated) {
    this.cached = this.cached || {};
    this.cached[this.storageKey(type, findArgs, opts)] = hydrated;
  },

  jsonMode: false,

  getPayload(method, data) {
    let payload = { method, data };

    if (this.jsonMode) {
      payload.contentType = "application/json";
      payload.data = JSON.stringify(data);
    }

    return payload;
  },

  update(store, type, id, attrs) {
    const data = {};
    const typeField = Ember.String.underscore(type);
    data[typeField] = attrs;

    return ajax(
      this.pathFor(store, type, id),
      this.getPayload("PUT", data)
    ).then(function(json) {
      return new Result(json[typeField], json);
    });
  },

  createRecord(store, type, attrs) {
    const data = {};
    const typeField = Ember.String.underscore(type);
    data[typeField] = attrs;
    return ajax(this.pathFor(store, type), this.getPayload("POST", data)).then(
      function(json) {
        return new Result(json[typeField], json);
      }
    );
  },

  destroyRecord(store, type, record) {
    return ajax(this.pathFor(store, type, record.get("id")), {
      method: "DELETE"
    });
  }
});
