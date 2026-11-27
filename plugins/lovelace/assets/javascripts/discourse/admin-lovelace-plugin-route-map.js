export default {
  resource: "admin.adminPlugins.show",
  path: "/plugins",

  map() {
    this.route("lovelace-checklist", { path: "checklist" });
    this.route("lovelace-onboarding", { path: "member-onboarding" });
  },
};
