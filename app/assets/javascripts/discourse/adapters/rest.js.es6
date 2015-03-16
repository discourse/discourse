const ADMIN_MODELS = ['plugin'];

export default Ember.Object.extend({
  pathFor(store, type, findArgs) {
    let path = "/" + Ember.String.underscore(store.pluralize(type));

    if (ADMIN_MODELS.indexOf(type) !== -1) { path = "/admin/" + path; }

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
    return Discourse.ajax(this.pathFor(store, type));
  },

  find(store, type, findArgs) {
    return Discourse.ajax(this.pathFor(store, type, findArgs));
  },

  update(store, type, id, attrs) {
    const data = {};
    data[Ember.String.underscore(type)] = attrs;
    return Discourse.ajax(this.pathFor(store, type, id), { method: 'PUT', data });
  },

  destroyRecord(store, type, record) {
    return Discourse.ajax(this.pathFor(store, type, record.get('id')), { method: 'DELETE' });
  }

});
