export default {
  resource: "user.preferences",

  map() {
    this.route("chat", { bundleName: "preferences-chat" });
  },
};
