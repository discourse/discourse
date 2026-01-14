export default {
  resource: "group",

  map() {
    this.route("reports", function () {
      this.route("show", { path: "/:query_id" });
    });
  },
};
