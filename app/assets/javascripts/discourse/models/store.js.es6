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
    return this.store.destroyRecord(type, this);
  }
});

export default Ember.Object.extend({
  findAll(type) {
    const adapter = this.container.lookup('adapter:' + type) || this.container.lookup('adapter:rest');
    const self = this;
    return adapter.findAll(this, type).then(function(result) {
      return result[Ember.String.underscore(type + 's')].map(obj => self._hydrate(type, obj));
    });
  },

  find(type, id) {
    const adapter = this.container.lookup('adapter:' + type) || this.container.lookup('adapter:rest');
    const self = this;
    return adapter.find(this, type, id).then(function(result) {
      return self._hydrate(type, result[Ember.String.underscore(type)]);
    });
  },

  update(type, id, attrs) {
    const adapter = this.container.lookup('adapter:' + type) || this.container.lookup('adapter:rest');
    return adapter.update(this, type, id, attrs, function(result) {
      if (result && result[type] && result[type].id) {
        const oldRecord = _identityMap[type][id];
        delete _identityMap[type][id];
        _identityMap[type][result[type].id] = oldRecord;
      }
      return result;
    });
  },

  createRecord(type, attrs) {
    return this._hydrate(type, attrs);
  },

  destroyRecord(type, record) {
    const adapter = this.container.lookup('adapter:' + type) || this.container.lookup('adapter:rest');
    return adapter.destroyRecord(this, type, record).then(function(result) {
      const forType = _identityMap[type];
      if (forType) { delete forType[record.get('id')]; }
      return result;
    });
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
