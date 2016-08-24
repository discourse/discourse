function resolveType(parsedName) {
  const entries = requirejs.entries;

  const named = `wizard/${parsedName.type}s/${parsedName.fullNameWithoutType}`;
  if (entries[named]) {
    const module = require(named, null, null, true /* force sync */);
    return module.default;
  }
}

export default Ember.DefaultResolver.extend({

  resolveRoute(parsedName) {
    return resolveType(parsedName) || this._super(parsedName);
  },

  resolveController(parsedName) {
    return resolveType(parsedName) || this._super(parsedName);
  },

  resolveTemplate(parsedName) {
    const templates = Ember.TEMPLATES;
    const withoutType = parsedName.fullNameWithoutType;
    return templates[`wizard/templates/${withoutType}`] || this._super(parsedName);
  }
});
