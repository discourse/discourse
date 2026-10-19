import DiscoursePostEventNestedAdapter from "./discourse-post-event-nested-adapter.js";

export default class DiscoursePostEventInvitee extends DiscoursePostEventNestedAdapter {
  apiNameFor() {
    return "invitee";
  }
}
