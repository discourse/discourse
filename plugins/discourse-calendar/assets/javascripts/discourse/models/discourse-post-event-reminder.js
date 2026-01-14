import RestModel from "discourse/models/rest";

export default class DiscoursePostEventReminder extends RestModel {
  init() {
    super.init(...arguments);

    this.__type = "discourse-post-event-reminder";
  }
}
