import Invite from "discourse/models/invite";
import debounce from "discourse/lib/debounce";
import { popupAjaxError } from "discourse/lib/ajax-error";

// This controller handles actions related to a user's invitations
export default Ember.Controller.extend({
  user: null,
  model: null,
  filter: null,
  totalInvites: null,
  invitesCount: null,
  canLoadMore: true,
  invitesLoading: false,
  reinvitedAll: false,
  rescindedAll: false,

  init: function() {
    this._super();
    this.set("searchTerm", "");
  },

  /**
    Observe the search term box with a debouncer and change the results.

    @observes searchTerm
  **/
  _searchTermChanged: debounce(function() {
    var self = this;
    Invite.findInvitedBy(
      self.get("user"),
      this.get("filter"),
      this.get("searchTerm")
    ).then(function(invites) {
      self.set("model", invites);
    });
  }, 250).observes("searchTerm"),

  inviteRedeemed: Em.computed.equal("filter", "redeemed"),

  showBulkActionButtons: function() {
    return (
      this.get("filter") === "pending" &&
      this.get("model").invites.length > 4 &&
      this.currentUser.get("staff")
    );
  }.property("filter"),

  /**
    Can the currently logged in user invite users to the site

    @property canInviteToForum
  **/
  canInviteToForum: function() {
    return Discourse.User.currentProp("can_invite_to_forum");
  }.property(),

  /**
    Can the currently logged in user bulk invite users to the site (only Admin is allowed to perform this operation)

    @property canBulkInvite
  **/
  canBulkInvite: function() {
    return Discourse.User.currentProp("admin");
  }.property(),

  /**
    Should the search filter input box be displayed?

    @property showSearch
  **/
  showSearch: function() {
    return this.get("totalInvites") > 9;
  }.property("totalInvites"),

  pendingLabel: function() {
    if (this.get("invitesCount.total") > 50) {
      return I18n.t("user.invited.pending_tab_with_count", {
        count: this.get("invitesCount.pending")
      });
    } else {
      return I18n.t("user.invited.pending_tab");
    }
  }.property("invitesCount"),

  redeemedLabel: function() {
    if (this.get("invitesCount.total") > 50) {
      return I18n.t("user.invited.redeemed_tab_with_count", {
        count: this.get("invitesCount.redeemed")
      });
    } else {
      return I18n.t("user.invited.redeemed_tab");
    }
  }.property("invitesCount"),

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
              this.get("model.invites").clear();
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
            .then(() => {
              this.set("reinvitedAll", true);
            })
            .catch(popupAjaxError);
        }
      });
    },

    loadMore() {
      var self = this;
      var model = self.get("model");

      if (self.get("canLoadMore") && !self.get("invitesLoading")) {
        self.set("invitesLoading", true);
        Invite.findInvitedBy(
          self.get("user"),
          self.get("filter"),
          self.get("searchTerm"),
          model.invites.length
        ).then(function(invite_model) {
          self.set("invitesLoading", false);
          model.invites.pushObjects(invite_model.invites);
          if (
            invite_model.invites.length === 0 ||
            invite_model.invites.length <
              Discourse.SiteSettings.invites_per_page
          ) {
            self.set("canLoadMore", false);
          }
        });
      }
    }
  }
});
