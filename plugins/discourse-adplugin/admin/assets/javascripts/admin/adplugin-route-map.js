export default {
  resource: "admin.adminPlugins",
  path: "/plugins",
  map() {
    this.route("houseAds", { path: "/pluginad/house_creatives" }, function () {
      this.route("index", { path: "/" });
      this.route("show", { path: "/:ad_id" });
    });
  },
};
