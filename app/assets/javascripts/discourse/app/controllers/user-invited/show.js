import Controller from "@ember/controller";
import { action } from "@ember/object";
import { equal, reads } from "@ember/object/computed";
import { service } from "@ember/service";
import { observes } from "@ember-decorators/object";
import CreateInvite from "discourse/components/modal/create-invite";
import CreateInviteBulk from "discourse/components/modal/create-invite-bulk";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed, { debounce } from "discourse/lib/decorators";
import { INPUT_DELAY } from "discourse/lib/environment";
import Invite from "discourse/models/invite";
import { i18n } from "discourse-i18n";

export default class UserInvitedShowController extends Controller {
  @service dialog;
  @service modal;
  @service toasts;

  user = null;
  model = null;
  filter = null;
  invitesCount = null;
  canLoadMore = true;
  invitesLoading = false;
  hasLoadedInitialInvites = false;
  reinvitedAll = false;
  searchTerm = "";

  @equal("filter", "redeemed") inviteRedeemed;
  @equal("filter", "expired") inviteExpired;
  @equal("filter", "pending") invitePending;
  @reads("currentUser.can_invite_to_forum") canInviteToForum;
  @reads("currentUser.admin") canBulkInvite;

  @observes("searchTerm")
  searchTermChanged() {
    this._searchTermChanged();
  }

  @debounce(INPUT_DELAY)
  _searchTermChanged() {
    Invite.findInvitedBy(this.user, this.filter, this.searchTerm).then(
      (invites) => this.set("model", invites)
    );
  }

  @discourseComputed("model")
  hasEmailInvites(model) {
    return model.invites.some((invite) => {
      return invite.email;
    });
  }

  @discourseComputed("model")
  showBulkActionButtons(model) {
    return model.invites.length > 0 && this.currentUser.staff;
  }

  @discourseComputed("invitesCount", "filter")
  showSearch(invitesCount, filter) {
    return invitesCount[filter] > 5;
  }

  @action
  createInvite() {
    this.modal.show(CreateInvite, { model: { invites: this.model.invites } });
  }

  @action
  createInviteCsv() {
    this.modal.show(CreateInviteBulk);
  }

  @action
  editInvite(invite) {
    this.modal.show(CreateInvite, { model: { editing: true, invite } });
  }

  @action
  async destroyInvite(invite) {
    try {
      await invite.destroy();
      this.model.invites.removeObject(invite);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  destroyAllExpired() {
    this.dialog.deleteConfirm({
      message: i18n("user.invited.remove_all_confirm"),
      didConfirm: () => {
        return Invite.destroyAllExpired(this.user)
          .then(() => {
            this.toasts.success({
              data: { message: i18n("user.invited.removed_all") },
            });
            this.send("triggerRefresh");
          })
          .catch(popupAjaxError);
      },
    });
  }

  @action
  reinvite(invite) {
    invite.reinvite();
    return false;
  }

  @action
  reinviteAll() {
    this.dialog.yesNoConfirm({
      message: i18n("user.invited.reinvite_all_confirm"),
      didConfirm: () => {
        return Invite.reinviteAll()
          .then(() => this.set("reinvitedAll", true))
          .catch(popupAjaxError);
      },
    });
  }

  @action
  loadMore() {
    const model = this.model;

    if (this.canLoadMore && !this.invitesLoading) {
      this.set("invitesLoading", true);
      Invite.findInvitedBy(
        this.user,
        this.filter,
        this.searchTerm,
        model.invites.length
      )
        .then((invite_model) => {
          this.set("invitesLoading", false);
          model.invites.pushObjects(invite_model.invites);
          if (
            invite_model.invites.length === 0 ||
            invite_model.invites.length < this.siteSettings.invites_per_page
          ) {
            this.set("canLoadMore", false);
          }
        })
        .finally(() => {
          this.set("hasLoadedInitialInvites", true);
        });
    }
  }
}
