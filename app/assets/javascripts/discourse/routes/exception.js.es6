import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  serialize() {
    return "";
  },

  actions: {
    didTransition() {
      this.controllerFor("application").set("showFooter", true);
      return true;
    }
  }
});
