import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  afterModel() {
    const params = this.paramsFor("editChildCategory");
    this.replaceWith(`/c/${params.parentSlug}/${params.slug}/edit/general`);
  },
});
