export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route("houseAds", { path: "house-ads" }, function () {
      this.route("show", { path: "/:id" });
    });
    this.route("dfpSettings", { path: "dfp-settings" }, function () {
      this.route("new");
      this.route("edit", { path: "/:id/edit" });
    });
  },
};
