function resolveType(parsedName) {
  const entries = requirejs.entries;

  const named = `wizard/${parsedName.type}s/${parsedName.fullNameWithoutType}`;
  if (entries[named]) {
    const module = require(named, null, null, true /* force sync */);
    return module.default;
  }
}

function customResolve(parsedName) {
  return resolveType(parsedName) || this._super(parsedName);
}

export default Ember.DefaultResolver.extend({

  resolveRoute: customResolve,
  resolveController: customResolve,
  resolveComponent: customResolve,

  resolveTemplate(parsedName) {
    const templates = Ember.TEMPLATES;
    const withoutType = parsedName.fullNameWithoutType;
    return templates[`wizard/templates/${withoutType}`] || this._super(parsedName);
  }
});
