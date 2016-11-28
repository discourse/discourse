/**
   A plugin outlet is an extension point for templates where other templates can
   be inserted by plugins.

   ## Usage

   If your handlebars template has:

   ```handlebars
     {{plugin-outlet "evil-trout"}}
   ```

   Then any handlebars files you create in the `connectors/evil-trout` directory
   will automatically be appended. For example:

   plugins/hello/assets/javascripts/discourse/templates/connectors/evil-trout/hello.hbs

   With the contents:

   ```handlebars
     <b>Hello World</b>
   ```

   Will insert <b>Hello World</b> at that point in the template.

   ## Disabling

   If a plugin returns a disabled status, the outlets will not be wired up for it.
   The list of disabled plugins is returned via the `Site` singleton.

**/
let _connectorCache, _templateCache;

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
  _templateCache = null;
  _connectorCache = null;
}

function buildConnectorCache() {
  _connectorCache = {};
  _templateCache = [];

  findOutlets(Ember.TEMPLATES, function(outletName, resource, uniqueName) {
    _connectorCache[outletName] = _connectorCache[outletName] || [];

    _connectorCache[outletName].push({
      templateName: resource.replace('javascripts/', ''),
      template: Ember.TEMPLATES[resource],
      classNames: `${outletName}-outlet ${uniqueName}`
    });
  });

  Object.keys(_connectorCache).forEach(outletName => {
    const connector = _connectorCache[outletName];
    (connector || []).forEach(s => {
      _templateCache.push(s.template);
      s.templateId = parseInt(_templateCache.length - 1);
    });
  });
}

// unbound version of outlets, only has a template
Handlebars.registerHelper('plugin-outlet', function(name) {
  if (!_connectorCache) { buildConnectorCache(); }

  const connector = _connectorCache[name];
  if (connector && connector.length) {
    const output = connector.map(c => c.template({context: this}));
    return new Handlebars.SafeString(output.join(""));
  }
});

const { registerKeyword } = Ember.__loader.require("ember-htmlbars/keywords");
const { internal } = Ember.__loader.require('htmlbars-runtime');

registerKeyword('plugin-outlet', {
  setupState(state, env, scope, params) {
    if (!_connectorCache) { buildConnectorCache(); }
    return { outletName: env.hooks.getValue(params[0]) };
  },

  render(renderNode, env, scope, params, hash, template, inverse, visitor) {
    let state = renderNode.getState();
    if (!state.outletName) { return true; }
    const connector = _connectorCache[state.outletName];
    if (!connector || connector.length === 0) { return true; }

    const listTemplate = Ember.TEMPLATES['outlet-list'];
    listTemplate.raw.locals = ['templateId', 'outletClasses', 'tagName'];

    internal.hostBlock(renderNode, env, scope, listTemplate.raw, null, null, visitor, function(options) {
      connector.forEach(source => {
        const tid = source.templateId;
        options.templates.template.yieldItem(`d-outlet-${tid}`, [
          tid,
          source.classNames,
          hash.tagName || 'div'
        ]);
      });
    });
    return true;
  }
});

registerKeyword('connector', function(morph, env, scope, params, hash, template, inverse, visitor) {
  template = _templateCache[parseInt(env.hooks.getValue(hash.templateId))];

  env.hooks.component(morph,
      env,
      scope,
      'connector-container',
      params,
      hash,
      { default: template.raw, inverse },
      visitor);
  return true;
});
