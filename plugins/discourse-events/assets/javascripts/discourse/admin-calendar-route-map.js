export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route("discourse-events-holidays", { path: "holidays" });
  },
};
