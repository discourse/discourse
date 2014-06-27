/**
   A plugin outlet is an extension point for templates where other templates can
   be inserted by plugins.

   ## Usage

   If you handlebars template has:

   ```handlebars
     {{plugin-outlet "evil-trout"}}
   ```

   Then any handlebars files you create in the `connectors/evil-trout` directory
   will automatically be appended. For example:

   plugins/hello/assets/javascripts/discourse/templates/connectors/evil-trout/hello.handlebars

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
**/

var _connectorCache;

function findOutlets(collection, callback) {
  Ember.keys(collection).forEach(function(i) {
    if (i.indexOf("/connectors/") !== -1) {
      var segments = i.split("/"),
          outletName = segments[segments.length-2],
          uniqueName = segments[segments.length-1];

      callback(outletName, i, uniqueName);
    }
  });
}

function buildConnectorCache() {
  _connectorCache = {};

  var uniqueViews = {};
  findOutlets(requirejs._eak_seen, function(outletName, idx, uniqueName) {
    _connectorCache[outletName] = _connectorCache[outletName] || [];

    var viewClass = require(idx, null, null, true).default;
    uniqueViews[uniqueName] = viewClass;
    _connectorCache[outletName].pushObject(viewClass);
  });

  findOutlets(Ember.TEMPLATES, function(outletName, idx, uniqueName) {
    _connectorCache[outletName] = _connectorCache[outletName] || [];

    var mixin = {templateName: idx.replace('javascripts/', '')},
        viewClass = uniqueViews[uniqueName];

    if (viewClass) {
      // We are going to add it back with the proper template
      _connectorCache[outletName].removeObject(viewClass);
    } else {
      viewClass = Em.View;
    }
    _connectorCache[outletName].pushObject(viewClass.extend(mixin));
  });

}

export default function(connectionName, options) {
  if (!_connectorCache) { buildConnectorCache(); }

  var self = this;
  if (_connectorCache[connectionName]) {
    var view,
        childViews = _connectorCache[connectionName].map(function(vc) {
          return vc.create({ context: self });
        });

    // If there is more than one view, create a container. Otherwise
    // just shove it in.
    if (childViews.length > 1) {
      view = Ember.ContainerView.extend({
        childViews: childViews
      });
    } else {
      view = childViews[0];
    }
    delete options.fn;  // we don't need the default template since we have a connector
    return Ember.Handlebars.helpers.view.call(this, view, options);
  } else if (options.fn) {

    // If a block is passed, render its content.
    return Ember.Handlebars.helpers.view.call(this,
              Ember.View.extend({
                isVirtual: true,
                tagName: '',
                template: function() {
                  return options.hash.template;
                }.property()
              }),
            options);
  }
}
