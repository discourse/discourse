import DiscourseRoute from "discourse/routes/discourse";
import ViewingActionType from "discourse/mixins/viewing-action-type";

export default DiscourseRoute.extend(ViewingActionType, {
  renderTemplate() {
    this.render("user-topics-list");
  },

  setupController(controller, model) {
    const userActionType = this.userActionType;
    this.controllerFor("user").set("userActionType", userActionType);
    this.controllerFor("user-activity").set("userActionType", userActionType);
    this.controllerFor("user-topics-list").setProperties({
      model,
      hideCategory: false
    });
  }
});
