import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default DiscourseRoute.extend({
  router: service(),
  showFooter: true,

  beforeModel() {
    this.router.transitionTo("group.manage.profile");
  },
});
