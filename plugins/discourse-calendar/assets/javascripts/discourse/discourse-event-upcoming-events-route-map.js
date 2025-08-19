export default function () {
  this.route(
    "discourse-post-event-upcoming-events",
    { path: "/upcoming-events" },
    function () {
      this.route("index", { path: "/" });
      this.route("mine");
    }
  );
}
