export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",

  map() {
    this.route("discourse-captcha-test", { path: "test" });
  },
};
