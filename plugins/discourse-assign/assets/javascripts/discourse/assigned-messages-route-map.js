export default {
  resource: "user.userPrivateMessages",

  map() {
    this.route("assigned", function () {
      this.route("index", { path: "/" });
    });
  },
};
