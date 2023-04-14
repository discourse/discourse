import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  beforeModel() {
    const appModel = this.modelFor("wizard");
    this.replaceWith("wizard.step", appModel.start);
  },
});
