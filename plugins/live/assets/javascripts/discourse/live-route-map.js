export default function () {
  this.route("live-room", { path: "/live/r/:slug" });
  this.route("live-room-invite", {
    path: "/live/r/:slug/invited-by/:username",
  });

  // Links shared before the plugin was renamed.
  this.route("live-room-legacy", { path: "/voice/r/:slug" });
  this.route("live-room-invite-legacy", {
    path: "/voice/r/:slug/invited-by/:username",
  });
}
