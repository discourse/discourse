export default function () {
  this.route("voice-room", {
    path: "/voice/r/:slug",
    bundleName: "voice-room",
  });
  this.route("voice-room-invite", {
    path: "/voice/r/:slug/invited-by/:username",
    bundleName: "voice-room",
  });
}
