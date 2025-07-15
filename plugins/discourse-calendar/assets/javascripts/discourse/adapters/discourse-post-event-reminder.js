import DiscoursePostEventNestedAdapter from "./discourse-post-event-nested-adapter";

export default class DiscoursePostEventReminder extends DiscoursePostEventNestedAdapter {
  apiNameFor() {
    return "reminder";
  }
}
