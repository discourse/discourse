import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  showFooter: true,

  beforeModel() {
    this.transitionTo("group.manage.profile");
  }
});
