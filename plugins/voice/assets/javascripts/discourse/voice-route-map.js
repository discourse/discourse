export default function () {
  this.route("voice-room", { path: "/voice/r/:slug" });
  this.route("voice-room-invite", {
    path: "/voice/r/:slug/invited-by/:username",
  });
}
