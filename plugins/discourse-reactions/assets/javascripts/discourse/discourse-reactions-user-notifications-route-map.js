export default {
  resource: "user.userNotifications",
  map() {
    this.route("reactionsReceived", { path: "reactions-received" });
  },
};
