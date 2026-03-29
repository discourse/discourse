export default {
  resource: "user.userActivity",
  map() {
    this.route("boostsGiven", { path: "boosts-given" });
  },
};
