export default function () {
  this.route("chat", { path: "/chat" }, function () {
    this.route("channel", { path: "/c/:channelTitle/:channelId" }, function () {
      this.route("near-message", { path: "/:messageId" });
      this.route("threads", { path: "/t" });
      this.route("thread", { path: "/t/:threadId" }, function () {
        this.route("near-message", { path: "/:messageId" });
      });
    });

    this.route(
      "channel.info",
      { path: "/c/:channelTitle/:channelId/info" },
      function () {
        this.route("about", { path: "/about" });
        this.route("members", { path: "/members" });
        this.route("settings", { path: "/settings" });
      }
    );

    this.route("browse", { path: "/browse" }, function () {
      this.route("all", { path: "/all" });
      this.route("closed", { path: "/closed" });
      this.route("open", { path: "/open" });
      this.route("archived", { path: "/archived" });
    });
    this.route("message", { path: "/message/:messageId" });
  });
}
