export default function () {
  this.route("chat", { path: "/chat" }, function () {
    // TODO(roman): Remove after the 3.1 release
    this.route("channel-legacy", {
      path: "/channel/:channelId/:channelTitle",
    });

    this.route("channel", { path: "/c/:channelTitle/:channelId" }, function () {
      this.route("from-params", { path: "/" });
      this.route("near-message", { path: "/:messageId" });

      this.route("info", { path: "/info" }, function () {
        this.route("about", { path: "/about" });
        this.route("members", { path: "/members" });
        this.route("settings", { path: "/settings" });
      });

      this.route("thread", { path: "/t/:threadId" });
    });

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
