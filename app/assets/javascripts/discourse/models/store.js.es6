import RestModel from 'discourse/models/rest';
import ResultSet from 'discourse/models/result-set';

const _identityMap = {};

export default Ember.Object.extend({
  pluralize(thing) {
    return thing + "s";
  },

  findAll(type) {
    const adapter = this.container.lookup('adapter:' + type) || this.container.lookup('adapter:rest');
    const self = this;
    return adapter.findAll(this, type).then(function(result) {
      return self._resultSet(type, result);
    });
  },

  find(type, findArgs) {
    const adapter = this.container.lookup('adapter:' + type) || this.container.lookup('adapter:rest');
    const self = this;
    return adapter.find(this, type, findArgs).then(function(result) {
      if (typeof findArgs === "object") {
        return self._resultSet(type, result);
      } else {
        return self._hydrate(type, result[Ember.String.underscore(type)]);
      }
    });
  },

  appendResults(resultSet, type, url) {
    const self = this;

    return Discourse.ajax(url).then(function(result) {
      const typeName = Ember.String.underscore(self.pluralize(type)),
            totalRows = result["total_rows_" + typeName] || result.get('totalRows'),
            loadMoreUrl = result["load_more_" + typeName],
            content = result[typeName].map(obj => self._hydrate(type, obj));

      resultSet.setProperties({ totalRows, loadMoreUrl });
      resultSet.get('content').pushObjects(content);

      // If we've loaded them all, clear the load more URL
      if (resultSet.get('length') >= totalRows) {
        resultSet.set('loadMoreUrl', null);
      }
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

  _resultSet(type, result) {
    const typeName = Ember.String.underscore(this.pluralize(type)),
          content = result[typeName].map(obj => this._hydrate(type, obj)),
          totalRows = result["total_rows_" + typeName] || content.length,
          loadMoreUrl = result["load_more_" + typeName];

    return ResultSet.create({ content, totalRows, loadMoreUrl, store: this, __type: type });
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
