export default {
  resource: "user.userNotifications",
  map() {
    this.route("boostsReceived", { path: "boosts" });
  },
};
