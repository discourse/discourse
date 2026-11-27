export default function () {
  this.route("my-event-registration-forms", {
    path: "/discourse-post-event/registration-forms/mine",
  });
  this.route("edit-event-registration-form", {
    path: "/discourse-post-event/registration-forms/:id/edit",
  });
  this.route("new-event-registration-form", {
    path: "/discourse-post-event/registration-forms/new",
  });
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
