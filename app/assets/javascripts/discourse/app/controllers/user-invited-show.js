import Controller from "@ember/controller";
import { action } from "@ember/object";
import { equal, reads } from "@ember/object/computed";
import bootbox from "bootbox";
import { INPUT_DELAY } from "discourse-common/config/environment";
import discourseDebounce from "discourse-common/lib/debounce";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import { popupAjaxError } from "discourse/lib/ajax-error";
import showModal from "discourse/lib/show-modal";
import Invite from "discourse/models/invite";
import I18n from "I18n";

export default Controller.extend({
  user: null,
  model: null,
  filter: null,
  invitesCount: null,
  canLoadMore: true,
  invitesLoading: false,
  reinvitedAll: false,
  removedAll: false,
  searchTerm: null,

  init() {
    this._super(...arguments);
    this.set("searchTerm", "");
  },

  @observes("searchTerm")
  _searchTermChanged() {
    discourseDebounce(
      this,
      function () {
        Invite.findInvitedBy(
          this.user,
          this.filter,
          this.searchTerm
        ).then((invites) => this.set("model", invites));
      },
      INPUT_DELAY
    );
  },

  inviteRedeemed: equal("filter", "redeemed"),
  inviteExpired: equal("filter", "expired"),
  invitePending: equal("filter", "pending"),

  @discourseComputed("model")
  hasEmailInvites(model) {
    return model.invites.some((invite) => {
      return invite.email;
    });
  },

  @discourseComputed("filter")
  showBulkActionButtons(filter) {
    return (
      filter === "pending" &&
      this.model.invites.length > 0 &&
      this.currentUser.staff
    );
  },

  canInviteToForum: reads("currentUser.can_invite_to_forum"),
  canBulkInvite: reads("currentUser.admin"),

  @discourseComputed("invitesCount", "filter")
  showSearch(invitesCount, filter) {
    return invitesCount[filter] > 5;
  },

  @action
  createInvite() {
    const controller = showModal("create-invite");
    controller.set("invites", this.model.invites);
  },

  @action
  createInviteCsv() {
    showModal("create-invite-bulk");
  },

  @action
  editInvite(invite) {
    const controller = showModal("create-invite");
    controller.set("editing", true);
    controller.setInvite(invite);
  },

  @action
  destroyInvite(invite) {
    invite.destroy();
    this.model.invites.removeObject(invite);
  },

  @action
  destroyAllExpired() {
    bootbox.confirm(I18n.t("user.invited.remove_all_confirm"), (confirm) => {
      if (confirm) {
        Invite.destroyAllExpired()
          .then(() => {
            this.set("removedAll", true);
            this.send("triggerRefresh");
          })
          .catch(popupAjaxError);
      }
    });
  },

  @action
  reinvite(invite) {
    invite.reinvite();
    return false;
  },

  @action
  reinviteAll() {
    bootbox.confirm(I18n.t("user.invited.reinvite_all_confirm"), (confirm) => {
      if (confirm) {
        Invite.reinviteAll()
          .then(() => this.set("reinvitedAll", true))
          .catch(popupAjaxError);
      }
    });
  },

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
      ).then((invite_model) => {
        this.set("invitesLoading", false);
        model.invites.pushObjects(invite_model.invites);
        if (
          invite_model.invites.length === 0 ||
          invite_model.invites.length < this.siteSettings.invites_per_page
        ) {
          this.set("canLoadMore", false);
        }
      });
    }
  },
});
