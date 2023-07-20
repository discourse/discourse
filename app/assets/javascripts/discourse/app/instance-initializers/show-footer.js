export default {
  initialize(owner) {
    const router = owner.lookup("router:main");
    const application = owner.lookup("controller:application");

    // only take care of hiding the footer here
    // controllers MUST take care of displaying it
    router.on("routeWillChange", () => {
      application.set("showFooter", false);
      return true;
    });
  },
};
