export default function () {
  this.route(
    "discourse-post-event-upcoming-events",
    { path: "/upcoming-events" },
    function () {
      this.route("index", { path: "/:view/:year/:month/:day" });
      this.route("default_index", { path: "/" });
      this.route("mine", { path: "/mine/:view/:year/:month/:day" });
      this.route("default_mine", { path: "/mine" });
    }
  );
}
