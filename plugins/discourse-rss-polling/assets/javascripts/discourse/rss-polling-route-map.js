/* eslint-disable ember/route-path-style */
export default {
  resource: "admin.adminPlugins",
  path: "/plugins",
  map() {
    this.route("rss_polling");
  },
};
