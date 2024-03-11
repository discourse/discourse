export default function () {
  this.route("chat", function () {
    this.route("channel", { path: "/c/:channelTitle/:channelId" }, function () {
      this.route("near-message", { path: "/:messageId" });
      this.route("near-message-with-thread", {
        path: "/:messageId/t/:threadId",
      });
      this.route("threads", { path: "/t" });
      this.route("thread", { path: "/t/:threadId" }, function () {
        this.route("near-message", { path: "/:messageId" });
      });
    });

    this.route("direct-messages");
    this.route("channels");
    this.route("threads");

    this.route("new-message");

    this.route(
      "channel.info",
      { path: "/c/:channelTitle/:channelId/info" },
      function () {
        this.route("members");
        this.route("settings");
      }
    );

    this.route("browse", function () {
      this.route("all");
      this.route("closed");
      this.route("open");
      this.route("archived");
    });
    this.route("message", { path: "/message/:messageId" });
  });
}
