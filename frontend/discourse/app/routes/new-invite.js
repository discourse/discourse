import { trackedArray } from "@ember/reactive/collections";
import { next } from "@ember/runloop";
import { service } from "discourse/lib/service";
import { homepageNavigationDestination } from "discourse/lib/homepage-router-overrides";
import { showCreateInviteModal } from "discourse/lib/invite-modal";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import CurrentUserService from "discourse/services/current-user";
import DialogService from "discourse/dialog-holder/services/dialog";

export default class extends DiscourseRoute {
  @service(() => CurrentUserService) currentUser;
  @service(() => DialogService) dialog;
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
      .replaceWith(homepageNavigationDestination())
      .followRedirects()
      .then(() => this.#openInviteModalIfAllowed());
  }

  #openInviteModalIfAllowed() {
    next(() => {
      if (this.currentUser.can_invite_to_forum) {
        showCreateInviteModal(this, {
          model: { invites: trackedArray() },
        });
      } else {
        this.dialog.alert(i18n("user.invited.cannot_invite_to_forum"));
      }
    });
  }
}
