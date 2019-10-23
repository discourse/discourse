import Controller from "@ember/controller";
import Invite from "discourse/models/invite";
import debounce from "discourse/lib/debounce";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";

export default Controller.extend({
  user: null,
  model: null,
  filter: null,
  totalInvites: null,
  invitesCount: null,
  canLoadMore: true,
  invitesLoading: false,
  reinvitedAll: false,
  rescindedAll: false,
  searchTerm: null,

  init() {
    this._super(...arguments);

    this.set("searchTerm", "");
  },

  @observes("searchTerm")
  _searchTermChanged: debounce(function() {
    Invite.findInvitedBy(this.user, this.filter, this.searchTerm).then(
      invites => this.set("model", invites)
    );
  }, 250),

  inviteRedeemed: Ember.computed.equal("filter", "redeemed"),

  @computed("filter")
  showBulkActionButtons(filter) {
    return (
      filter === "pending" &&
      this.model.invites.length > 4 &&
      this.currentUser.get("staff")
    );
  },

  canInviteToForum: Ember.computed.reads("currentUser.can_invite_to_forum"),

  canBulkInvite: Ember.computed.reads("currentUser.admin"),

  showSearch: Ember.computed.gte("totalInvites", 10),

  @computed("invitesCount.total", "invitesCount.pending")
  pendingLabel(invitesCountTotal, invitesCountPending) {
    if (invitesCountTotal > 50) {
      return I18n.t("user.invited.pending_tab_with_count", {
        count: invitesCountPending
      });
    } else {
      return I18n.t("user.invited.pending_tab");
    }
  },

  @computed("invitesCount.total", "invitesCount.redeemed")
  redeemedLabel(invitesCountTotal, invitesCountRedeemed) {
    if (invitesCountTotal > 50) {
      return I18n.t("user.invited.redeemed_tab_with_count", {
        count: invitesCountRedeemed
      });
    } else {
      return I18n.t("user.invited.redeemed_tab");
    }
  },

  actions: {
    rescind(invite) {
      invite.rescind();
      return false;
    },

    rescindAll() {
      bootbox.confirm(I18n.t("user.invited.rescind_all_confirm"), confirm => {
        if (confirm) {
          Invite.rescindAll()
            .then(() => {
              this.set("rescindedAll", true);
            })
            .catch(popupAjaxError);
        }
      });
    },

    reinvite(invite) {
      invite.reinvite();
      return false;
    },

    reinviteAll() {
      bootbox.confirm(I18n.t("user.invited.reinvite_all_confirm"), confirm => {
        if (confirm) {
          Invite.reinviteAll()
            .then(() => this.set("reinvitedAll", true))
            .catch(popupAjaxError);
        }
      });
    },

    loadMore() {
      const model = this.model;

      if (this.canLoadMore && !this.invitesLoading) {
        this.set("invitesLoading", true);
        Invite.findInvitedBy(
          this.user,
          this.filter,
          this.searchTerm,
          model.invites.length
        ).then(invite_model => {
          this.set("invitesLoading", false);
          model.invites.pushObjects(invite_model.invites);
          if (
            invite_model.invites.length === 0 ||
            invite_model.invites.length <
              Discourse.SiteSettings.invites_per_page
          ) {
            this.set("canLoadMore", false);
          }
        });
      }
    }
  }
});
