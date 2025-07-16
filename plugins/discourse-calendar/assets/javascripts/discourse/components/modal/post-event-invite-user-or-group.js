import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";

export default class PostEventInviteUserOrGroup extends Component {
  @tracked invitedNames = [];
  @tracked flash = null;

  @action
  async invite() {
    try {
      await ajax(
        `/discourse-post-event/events/${this.args.model.event.id}/invite.json`,
        {
          data: { invites: this.invitedNames },
          type: "POST",
        }
      );
      this.args.closeModal();
    } catch (e) {
      this.flash = extractError(e);
    }
  }
}
