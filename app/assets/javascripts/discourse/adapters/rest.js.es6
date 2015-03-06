const ADMIN_MODELS = ['plugin'];

export default Ember.Object.extend({
  pathFor(type, id) {
    let path = "/" + Ember.String.underscore(type + 's');

    if (ADMIN_MODELS.indexOf(type) !== -1) { path = "/admin/" + path; }
    if (id) { path += "/" + id; }

    return path;
  },

  findAll(store, type) {
    return Discourse.ajax(this.pathFor(type));
  },

  find(store, type, id) {
    return Discourse.ajax(this.pathFor(type, id));
  },

  update(store, type, id, attrs) {
    const data = {};
    data[Ember.String.underscore(type)] = attrs;
    return Discourse.ajax(this.pathFor(type, id), { method: 'PUT', data });
  },

  destroyRecord(store, type, record) {
    return Discourse.ajax(this.pathFor(type, record.get('id')), { method: 'DELETE' });
  }

});
