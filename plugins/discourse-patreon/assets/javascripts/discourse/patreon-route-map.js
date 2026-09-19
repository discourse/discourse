export default {
  resource: "admin.adminPlugins.show",

  map() {
    // Route names are shared across every plugin nested under the show route,
    // so this one keeps the plugin prefix.
    this.route("patreon-filters", { path: "filters" });
  },
};
