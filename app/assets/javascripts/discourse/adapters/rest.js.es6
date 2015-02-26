const ADMIN_MODELS = ['plugin'];

const _identityMap = {};

const RestModel = Ember.Object.extend({
  update(attrs) {
    const self = this;
    return this.store.update(this.get('__type'), this.get('id'), attrs).then(function(result) {
      self.setProperties(attrs);
      return result;
    });
  }
});

export default Ember.Object.extend({
  serverName(type) {
    return Ember.String.underscore(type + 's');
  },

  pathFor(type, id) {
    let path = "/" + this.serverName(type);

    if (ADMIN_MODELS.indexOf(type) !== -1) { path = "/admin/" + path; }
    if (id) { path += "/" + id; }

    return path;
  },

  findAll(type) {
    var self = this;
    return Discourse.ajax(this.pathFor(type)).then(function(result) {
      return result[self.serverName(type)].map(obj => self._hydrate(type, obj));
    });
  },

  find(type, id) {
    var self = this;
    return Discourse.ajax(this.pathFor(type, id)).then(function(result) {
      return self._hydrate(type, result[self.serverName(type)]);
    });
  },

  update(type, id, attrs) {
    const data = {};
    data[this.serverName(type)] = attrs;

    return Discourse.ajax(this.pathFor(type, id), { method: 'PUT', data });
  },

  _hydrate(type, obj) {
    if (!obj) { throw "Can't hydrate " + type + " of `null`"; }
    if (!obj.id) { throw "Can't hydrate " + type + " without an `id`"; }

    _identityMap[type] = _identityMap[type] || {};

    const existing = _identityMap[type][obj.id];
    if (existing) {
      delete obj.id;
      existing.setProperties(obj);
      return existing;
    }

    obj.store = this;
    obj.__type = type;

    const klass = this.container.lookupFactory('model:' + type) || RestModel;
    const model = klass.create(obj);
    _identityMap[type][obj.id] = model;
    return model;
  }

});
