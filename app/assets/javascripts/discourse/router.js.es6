const rootURL = Discourse.BaseUri && Discourse.BaseUri !== "/" ? Discourse.BaseUri : undefined;

const BareRouter = Ember.Router.extend({
  rootURL,
  location: Ember.testing ? 'none': 'discourse-location'
});

export function mapRoutes() {

  var Router = BareRouter.extend();
  const resources = {};
  const paths = {};

  // If a module is defined as `route-map` in discourse or a plugin, its routes
  // will be built automatically. You can supply a `resource` property to
  // automatically put it in that resource, such as `admin`. That way plugins
  // can define admin routes.
  Ember.keys(requirejs._eak_seen).forEach(function(key) {
    if (/route-map$/.test(key)) {
      var module = require(key, null, null, true);
      if (!module || !module.default) { throw new Error(key + ' must export a route map.'); }

      var mapObj = module.default;
      if (typeof mapObj === 'function') {
        mapObj = { resource: 'root', map: mapObj };
      }

      if (!resources[mapObj.resource]) { resources[mapObj.resource] = []; }
      resources[mapObj.resource].push(mapObj.map);
      if (mapObj.path) { paths[mapObj.resource] = mapObj.path; }
    }
  });

  return Router.map(function() {
    var router = this;

    // Do the root resources first
    if (resources.root) {
      resources.root.forEach(function(m) {
        m.call(router);
      });
      delete resources.root;
    }

    // Even if no plugins set it up, we need an `adminPlugins` route
    var adminPlugins = 'admin.adminPlugins';
    resources[adminPlugins] = resources[adminPlugins] || [Ember.K];
    paths[adminPlugins] = paths[adminPlugins] || "/plugins";

    var segments = {},
        standalone = [];

    Object.keys(resources).forEach(function(r) {
      var m = /^([^\.]+)\.(.*)$/.exec(r);
      if (m) {
        segments[m[1]] = m[2];
      } else {
        standalone.push(r);
      }
    });

    // Apply other resources next. A little hacky but works!
    standalone.forEach(function(r) {
      router.resource(r, {path: paths[r]}, function() {
        var res = this;
        resources[r].forEach(function(m) { m.call(res); });

        var s = segments[r];
        if (s) {
          var full = r + '.' + s;
          res.resource(s, {path: paths[full]}, function() {
            var nestedRes = this;
            resources[full].forEach(function(m) { m.call(nestedRes); });
          });
        }
      });
    });

    this.route('unknown', {path: '*path'});
  });
}

export default BareRouter;
