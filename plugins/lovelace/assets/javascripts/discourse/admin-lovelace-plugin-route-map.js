export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",
  map() {
    this.route("lovelace-onboarding", { path: "member-onboarding" });
  },
};
