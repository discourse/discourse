const ADMIN_MODELS = ['plugin'];

const _identityMap = {};

const RestModel = Ember.Object.extend({
  update(attrs) {
    const self = this,
          type = this.get('__type');
    return this.store.update(type, this.get('id'), attrs).then(function(result) {
      if (result && result[type]) {
        Object.keys(result).forEach(function(k) {
          attrs[k] = result[k];
        });
      }
      self.setProperties(attrs);
      return result;
    });
  },

  destroyRecord() {
    const type = this.get('__type');
    return this.store.destroyRecord(type, this.get('id'));
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
    data[Ember.String.underscore(type)] = attrs;

    return Discourse.ajax(this.pathFor(type, id), { method: 'PUT', data }).then(function (result) {
      if (result && result[type] && result[type].id) {
        const oldRecord = _identityMap[type][id];
        delete _identityMap[type][id];
        _identityMap[type][result[type].id] = oldRecord;
      }
      return result;
    });
  },

  destroyRecord(type, id) {
    return Discourse.ajax(this.pathFor(type, id), { method: 'DELETE' }).then(function(result) {
      delete _identityMap[type][id];
      return result;
    });
  },

  createRecord(type, attrs) {
    return this._hydrate(type, attrs);
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
