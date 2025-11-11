export default {
  resource: "admin.adminPlugins",
  path: "/plugins",
  map() {
    this.route("rss_polling");
  },
};
