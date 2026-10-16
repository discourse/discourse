import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { setPendingInviteRef } from "discourse/plugins/live/discourse/lib/live/invite-ref";

// An invite link (/live/r/:slug/invited-by/:username) is the room page
// with the inviter remembered: the ref is held until the user actually joins
// the call, so the server credits the inviter on a real join, not a page view.
export default class LiveRoomInviteRoute extends DiscourseRoute {
  @service router;

  model(params, transition) {
    setPendingInviteRef(params.slug, params.username);
    this.router.replaceWith("live-room", params.slug, {
      queryParams: transition.to.queryParams,
    });
  }
}
