export default {
  after: "inject-objects",

  initialize(owner) {
    const enabled =
      document.querySelector("meta[name=discourse-engagement-tracking-enabled]")
        ?.content === "true";
    if (!enabled) {
      return;
    }

    owner.lookup("service:human-activity-tracker").start();
  },
};
