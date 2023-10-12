import { inject as service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  router: service(),
  beforeModel() {
    const appModel = this.modelFor("wizard");
    this.router.replaceWith("wizard.step", appModel.start);
  },
});
