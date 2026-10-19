import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { setPendingInviteRef } from "discourse/plugins/voice/discourse/lib/voice/invite-ref";

// An invite link (/voice/r/:slug/invited-by/:username) is the room page
// with the inviter remembered: the ref is held until the user actually joins
// the call, so the server credits the inviter on a real join, not a page view.
export default class VoiceRoomInviteRoute extends DiscourseRoute {
  @service router;

  model(params, transition) {
    setPendingInviteRef(params.slug, params.username);
    this.router.replaceWith("voice-room", params.slug, {
      queryParams: transition.to.queryParams,
    });
  }
}
