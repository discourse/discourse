import DiscoursePostEventNestedAdapter from "./discourse-post-event-nested-adapter";

export default class DiscoursePostEventInvitee extends DiscoursePostEventNestedAdapter {
  apiNameFor() {
    return "invitee";
  }
}
