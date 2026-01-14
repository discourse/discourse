export default {
  resource: "admin.adminPlugins",
  path: "/plugins",

  map() {
    this.route("discourse-subscriptions", function () {
      this.route("products", function () {
        this.route("show", { path: "/:product-id" }, function () {
          this.route("plans", function () {
            this.route("show", { path: "/:plan-id" });
          });
        });
      });

      this.route("coupons");

      this.route("subscriptions");
    });
  },
};
