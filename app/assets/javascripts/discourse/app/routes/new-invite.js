import { next } from "@ember/runloop";
import { service } from "@ember/service";
import CreateInvite from "discourse/components/modal/create-invite";
import cookie from "discourse/lib/cookie";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class extends DiscourseRoute {
  @service router;
  @service modal;
  @service dialog;
  @service currentUser;

  async beforeModel(transition) {
    if (this.currentUser) {
      if (transition.from) {
        // when navigating from another ember route
        transition.abort();
        this.#openInviteModalIfAllowed();
      } else {
        // when landing on this route from a full page load
        this.router
          .replaceWith("discovery.latest")
          .followRedirects()
          .then(() => {
            this.#openInviteModalIfAllowed();
          });
      }
    } else {
      cookie("destination_url", window.location.href);
      this.router.replaceWith("login");
    }
  }

  #openInviteModalIfAllowed() {
    next(() => {
      if (this.currentUser.can_invite_to_forum) {
        this.modal.show(CreateInvite, { model: { invites: [] } });
      } else {
        this.dialog.alert(i18n("user.invited.cannot_invite_to_forum"));
      }
    });
  }
}
