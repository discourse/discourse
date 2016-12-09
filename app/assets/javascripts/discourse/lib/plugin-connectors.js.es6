let _connectorCache;
let _extraConnectorClasses = {};

export function resetExtraClasses() {
  _extraConnectorClasses = {};
}

// Note: In plugins, define a class by path and it will be wired up automatically
// eg: discourse/connectors/<OUTLET NAME>/<CONNECTOR NAME>.js.es6
export function extraConnectorClass(name, obj) {
  _extraConnectorClasses[name] = obj;
}

const DefaultConnectorClass = {
  actions: {},
  shouldRender: () => true
};

function findOutlets(collection, callback) {
  const disabledPlugins = Discourse.Site.currentProp('disabled_plugins') || [];

  Object.keys(collection).forEach(function(res) {
    if (res.indexOf("/connectors/") !== -1) {
      // Skip any disabled plugins
      for (let i=0; i<disabledPlugins.length; i++) {
        if (res.indexOf("/" + disabledPlugins[i] + "/") !== -1) {
          return;
        }
      }

      const segments = res.split("/");
      let outletName = segments[segments.length-2];
      const uniqueName = segments[segments.length-1];

      callback(outletName, res, uniqueName);
    }
  });
}

export function clearCache() {
  _connectorCache = null;
}

function buildConnectorCache() {
  _connectorCache = {};

  findOutlets(Ember.TEMPLATES, function(outletName, resource, uniqueName) {
    _connectorCache[outletName] = _connectorCache[outletName] || [];

    const foundClass = _extraConnectorClasses[`${outletName}/${uniqueName}`];
    const connectorClass = foundClass ?
      jQuery.extend({}, DefaultConnectorClass, foundClass) :
      DefaultConnectorClass;

    _connectorCache[outletName].push({
      templateName: resource.replace('javascripts/', ''),
      template: Ember.TEMPLATES[resource],
      classNames: `${outletName}-outlet ${uniqueName}`,
      connectorClass
    });
  });
}

export function connectorsFor(outletName) {
  if (!_connectorCache) { buildConnectorCache(); }
  return _connectorCache[outletName] || [];
}
