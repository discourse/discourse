export default function () {
  this.route(
    "user",
    { path: "/u/:username", resetNamespace: true },
    function () {
      this.route("userActivity", function () {
        this.route("rewind");
      });
    }
  );
}
