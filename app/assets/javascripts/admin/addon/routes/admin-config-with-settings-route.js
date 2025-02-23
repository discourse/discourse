import DiscourseRoute from "discourse/routes/discourse";

export default class AdminConfigWithSettingsRoute extends DiscourseRoute {
  resetController(controller, isExiting) {
    // Have to do this because this is the parent route. We don't want to have
    // to make a controller for every single settings route when we can reset
    // the filter here.
    const settingsController = this.controllerFor(
      `${this.fullRouteName}.settings`
    );
    if (isExiting) {
      settingsController.set("filter", "");
    }
  }
}
