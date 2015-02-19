const ADMIN_MODELS = ['plugin'];

function plural(type) {
  return type + 's';
}

function pathFor(type) {
  const path = "/" + plural(type);

  if (ADMIN_MODELS.indexOf(type) !== -1) {
    return "/admin/" + path;
  }

  return path;
}

const _identityMap = {};

export default Ember.Object.extend({
  findAll(type) {
    var self = this;
    return Discourse.ajax(pathFor(type)).then(function(result) {
      return result[plural(type)].map(obj => self._hydrate(type, obj));
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

    const klass = this.container.lookupFactory('model:' + type) || Ember.Object;
    const model = klass.create(obj);
    _identityMap[type][obj.id] = model;
    return model;
  }

});
