export default function () {
  this.route("chat", { path: "/chat" }, function () {
    this.route(
      "channel",
      { path: "/channel/:channelId/:channelTitle" },
      function () {
        this.route("info", { path: "/info" }, function () {
          this.route("about", { path: "/about" });
          this.route("members", { path: "/members" });
          this.route("settings", { path: "/settings" });
        });
      }
    );

    this.route("draft-channel", { path: "/draft-channel" });
    this.route("browse", { path: "/browse" }, function () {
      this.route("all", { path: "/all" });
      this.route("closed", { path: "/closed" });
      this.route("open", { path: "/open" });
      this.route("archived", { path: "/archived" });
    });
    this.route("message", { path: "/message/:messageId" });
  });
}
