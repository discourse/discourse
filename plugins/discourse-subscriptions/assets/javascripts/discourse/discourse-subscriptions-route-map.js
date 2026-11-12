/* eslint-disable ember/routes-segments-snake-case */
export default {
  resource: "admin.adminPlugins.show",

  map() {
    // Route names are shared across every plugin nested under the show route,
    // so they are prefixed. The paths keep the URLs they had before.
    this.route(
      "discourse-subscriptions-products",
      { path: "products" },
      function () {
        this.route("show", { path: "/:product-id" }, function () {
          this.route("plans", function () {
            this.route("show", { path: "/:plan-id" });
          });
        });
      }
    );

    this.route("discourse-subscriptions-coupons", { path: "coupons" });

    this.route("discourse-subscriptions-subscriptions", {
      path: "subscriptions",
    });
  },
};
