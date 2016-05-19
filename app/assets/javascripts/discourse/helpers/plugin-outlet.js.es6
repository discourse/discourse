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

   Optionally you can also define a view class for the outlet as:

   plugins/hello/assets/javascripts/discourse/views/connectors/evil-trout/hello.js.es6

   And it will be wired up automatically.

   ## The block form

   If you use the block form of the outlet, its contents will be displayed
   if no connectors are found. Example:

   ```handlebars
     {{#plugin-outlet "hello-world"}}
       Nobody says hello :'(
     {{/plugin-outlet}}
   ```

   ## Disabling

   If a plugin returns a disabled status, the outlets will not be wired up for it.
   The list of disabled plugins is returned via the `Site` singleton.

**/
import { registerHelper } from 'discourse/lib/helpers';

let _connectorCache, _rawCache;

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

function buildConnectorCache() {
  _connectorCache = {};
  _rawCache = {};

  const uniqueViews = {};
  findOutlets(requirejs._eak_seen, function(outletName, resource, uniqueName) {
    _connectorCache[outletName] = _connectorCache[outletName] || [];

    const viewClass = require(resource, null, null, true).default;
    uniqueViews[uniqueName] = viewClass;
    _connectorCache[outletName].pushObject(viewClass);
  });

  findOutlets(Ember.TEMPLATES, function(outletName, resource, uniqueName) {
    _connectorCache[outletName] = _connectorCache[outletName] || [];

    const mixin = {templateName: resource.replace('javascripts/', '')};
    let viewClass = uniqueViews[uniqueName];

    if (viewClass) {
      // We are going to add it back with the proper template
      _connectorCache[outletName].removeObject(viewClass);
    } else {
      if (!/\.raw$/.test(uniqueName)) {
        viewClass = Ember.View.extend({ classNames: [outletName + '-outlet', uniqueName] });
      }
    }

    if (viewClass) {
      _connectorCache[outletName].pushObject(viewClass.extend(mixin));
    } else {
      // we have a raw template
      if (!_rawCache[outletName]) {
        _rawCache[outletName] = [];
      }

      _rawCache[outletName].push(Ember.TEMPLATES[resource]);
    }
  });

}

var _viewInjections;
function viewInjections(container) {
  if (_viewInjections) { return _viewInjections; }

  const injections = container._registry.getTypeInjections('view');

  _viewInjections = {};
  injections.forEach(function(i) {
    _viewInjections[i.property] = container.lookup(i.fullName);
  });

  return _viewInjections;
}

// unbound version of outlets, only has a template
Handlebars.registerHelper('plugin-outlet', function(name){
  if (!_rawCache) { buildConnectorCache(); }

  const functions = _rawCache[name];
  if (functions) {
    var output = [];

    for(var i=0; i<functions.length; i++){
      output.push(functions[i]({context: this}));
    }

    return new Handlebars.SafeString(output.join(""));
  }

});

registerHelper('plugin-outlet', function(params, hash, options, env) {
  const connectionName = params[0];

  if (!_connectorCache) { buildConnectorCache(); }

  if (_connectorCache[connectionName]) {
    const childViews = _connectorCache[connectionName];

    // If there is more than one view, create a container. Otherwise
    // just shove it in.
    const viewClass = (childViews.length > 1) ? Ember.ContainerView : childViews[0];

    const newHash = $.extend({}, viewInjections(env.data.view.container));
    if (hash.tagName) { newHash.tagName = hash.tagName; }

    delete options.fn;  // we don't need the default template since we have a connector
    env.helpers.view.helperFunction.call(this, [viewClass], newHash, options, env);

    const cvs = env.data.view._childViews;
    if (childViews.length > 1 && cvs && cvs.length) {
      const inserted = cvs[cvs.length-1];
      if (inserted) {
        childViews.forEach(function(cv) {
          inserted.pushObject(cv.create());
        });
      }
    }
  }
});

// No longer used
export function rewire() { }
