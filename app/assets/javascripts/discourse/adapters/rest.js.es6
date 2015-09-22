import StaleResult from 'discourse/lib/stale-result';
const ADMIN_MODELS = ['plugin', 'site-customization', 'embeddable-host'];

export function Result(payload, responseJson) {
  this.payload = payload;
  this.responseJson = responseJson;
  this.target = null;
}

const ajax = Discourse.ajax;

// We use this to make sure 404s are caught
function rethrow(error) {
  if (error.status === 404) {
    throw "404: " + error.responseText;
  }
  throw(error);
}

export default Ember.Object.extend({

  basePath(store, type) {
    if (ADMIN_MODELS.indexOf(type.replace('_', '-')) !== -1) { return "/admin/"; }
    return "/";
  },

  pathFor(store, type, findArgs) {
    let path = this.basePath(store, type, findArgs) + Ember.String.underscore(store.pluralize(type));

    if (findArgs) {
      if (typeof findArgs === "object") {
        const queryString = Object.keys(findArgs)
                                  .reject(k => !findArgs[k])
                                  .map(k => k + "=" + encodeURIComponent(findArgs[k]));

        if (queryString.length) {
          path += "?" + queryString.join('&');
        }
      } else {
        // It's serializable as a string if not an object
        path += "/" + findArgs;
      }
    }

    return path;
  },

  findAll(store, type) {
    return ajax(this.pathFor(store, type)).catch(rethrow);
  },


  find(store, type, findArgs) {
    return ajax(this.pathFor(store, type, findArgs)).catch(rethrow);
  },

  findStale() {
    return new StaleResult();
  },

  update(store, type, id, attrs) {
    const data = {};
    const typeField = Ember.String.underscore(type);
    data[typeField] = attrs;
    return ajax(this.pathFor(store, type, id), { method: 'PUT', data }).then(function(json) {
      return new Result(json[typeField], json);
    });
  },

  createRecord(store, type, attrs) {
    const data = {};
    const typeField = Ember.String.underscore(type);
    data[typeField] = attrs;
    return ajax(this.pathFor(store, type), { method: 'POST', data }).then(function (json) {
      return new Result(json[typeField], json);
    });
  },

  destroyRecord(store, type, record) {
    return ajax(this.pathFor(store, type, record.get('id')), { method: 'DELETE' });
  }

});
