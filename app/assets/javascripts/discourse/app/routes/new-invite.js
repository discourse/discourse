import { next } from "@ember/runloop";
import { service } from "@ember/service";
import CreateInvite from "discourse/components/modal/create-invite";
import { defaultHomepage } from "discourse/lib/utilities";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class extends DiscourseRoute {
  @service currentUser;
  @service dialog;
  @service modal;
  @service router;

  async beforeModel(transition) {
    if (!this.currentUser) {
      transition.send("showLogin");
      return;
    }

    // when navigating from another ember route
    if (transition.from) {
      transition.abort();
      this.#openInviteModalIfAllowed();
      return;
    }

    // when landing on the route from a full page load
    this.router
      .replaceWith(`discovery.${defaultHomepage()}`)
      .followRedirects()
      .then(() => this.#openInviteModalIfAllowed());
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
