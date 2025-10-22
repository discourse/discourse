export default function () {
  this.route("subscriptions", { path: "/s/subscriptions" });
  this.route("subscribe", { path: "/s" }, function () {
    this.route("show", { path: "/:subscription-id" });
  });
}
