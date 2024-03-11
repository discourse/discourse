import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  router: service(),

  afterModel() {
    const params = this.paramsFor("editCategory");
    this.router.replaceWith(`/c/${params.slug}/edit/general`);
  },
});
