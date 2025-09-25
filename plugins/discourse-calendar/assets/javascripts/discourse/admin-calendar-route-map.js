export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route("discourse-calendar-holidays", { path: "holidays" });
  },
};
