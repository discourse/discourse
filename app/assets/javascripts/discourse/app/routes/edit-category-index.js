import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  afterModel() {
    const params = this.paramsFor("editCategory");
    this.replaceWith(`/c/${params.slug}/edit/general`);
  },
});
