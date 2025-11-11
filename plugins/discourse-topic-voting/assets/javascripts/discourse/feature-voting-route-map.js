export default {
  resource: "user",
  path: "users/:username",
  map() {
    this.route(
      "userActivity",
      { path: "activity", resetNamespace: true },
      function () {
        this.route("votes");
      }
    );
  },
};
