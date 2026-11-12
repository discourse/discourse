import DiscoursePostEventNestedAdapter from "./discourse-post-event-nested-adapter.js";

export default class DiscoursePostEventReminder extends DiscoursePostEventNestedAdapter {
  apiNameFor() {
    return "reminder";
  }
}
