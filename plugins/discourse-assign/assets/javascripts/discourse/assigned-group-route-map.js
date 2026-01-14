export default {
  resource: "group",

  map() {
    this.route("assigned", function () {
      this.route("show", { path: "/:filter" });
    });
  },
};
