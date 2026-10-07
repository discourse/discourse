export default {
  after: "inject-objects",

  initialize(owner) {
    owner.lookup("service:human-activity-tracker").start();
  },
};
