export default {
  name: "show-footer",

  initialize(container) {
    const router = container.lookup("router:main");
    const application = container.lookup("controller:application");

    // only take care of hiding the footer here
    // controllers MUST take care of displaying it
    router.on("willTransition", () => {
      application.set("showFooter", false);
      return true;
    });
  }
};
