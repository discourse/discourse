import DiscourseRoute from "discourse/routes/discourse";
import { inject as service } from "@ember/service";

export default DiscourseRoute.extend({
  router: service(),

  afterModel() {
    const params = this.paramsFor("editCategory");
    this.router.replaceWith(`/c/${params.slug}/edit/general`);
  },
});
