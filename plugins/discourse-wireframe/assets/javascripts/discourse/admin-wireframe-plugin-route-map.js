export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",

  map() {
    this.route("wireframe-designs", { path: "wireframe-templates" });
  },
};
