import { and, readOnly } from "@ember/object/computed";
import Component from "@ember/component";
import Group from "discourse/models/group";
import I18n from "I18n";
import Invite from "discourse/models/invite";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  inviteModel: readOnly("panel.model.inviteModel"),
  userInvitedShow: readOnly("panel.model.userInvitedShow"),
  isStaff: readOnly("currentUser.staff"),
  isAdmin: readOnly("currentUser.admin"),
  maxRedemptionAllowed: 5,
  inviteExpiresAt: moment().add(1, "month").format("YYYY-MM-DD"),
  groupIds: null,
  allGroups: null,

  init() {
    this._super(...arguments);
    this.setDefaultSelectedGroups();
    this.setGroupOptions();
  },

  willDestroyElement() {
    this._super(...arguments);
    this.reset();
  },

  @discourseComputed("isStaff", "inviteModel.saving", "maxRedemptionAllowed")
  disabled(isStaff, saving, canInviteTo, maxRedemptionAllowed) {
    if (saving) {
      return true;
    }
    if (!isStaff) {
      return true;
    }
    if (maxRedemptionAllowed < 2) {
      return true;
    }

    return false;
  },

  errorMessage: I18n.t("user.invited.invite_link.error"),

  @discourseComputed("isAdmin", "inviteModel.group_users")
  showGroups(isAdmin, groupUsers) {
    return (
      isAdmin || (groupUsers && groupUsers.some((groupUser) => groupUser.owner))
    );
  },

  showApprovalMessage: and("isStaff", "siteSettings.must_approve_users"),

  reset() {
    this.setProperties({
      maxRedemptionAllowed: 5,
      groupIds: [],
    });

    this.inviteModel.setProperties({
      error: false,
      saving: false,
      finished: false,
      inviteLink: null,
    });
  },

  @action
  generateMultipleUseInviteLink() {
    if (this.disabled) {
      return;
    }

    const groupIds = this.groupIds;
    const maxRedemptionAllowed = this.maxRedemptionAllowed;
    const inviteExpiresAt = this.inviteExpiresAt;
    const userInvitedController = this.userInvitedShow;
    const model = this.inviteModel;
    model.setProperties({ saving: true, error: false });

    return model
      .generateMultipleUseInviteLink(
        groupIds,
        maxRedemptionAllowed,
        inviteExpiresAt
      )
      .then((result) => {
        model.setProperties({
          saving: false,
          finished: true,
          inviteLink: result.link,
        });

        if (userInvitedController) {
          Invite.findInvitedBy(
            this.currentUser,
            userInvitedController.filter
          ).then((inviteModel) => {
            userInvitedController.setProperties({
              model: inviteModel,
              totalInvites: inviteModel.invites.length,
            });
          });
        }
      })
      .catch((e) => {
        if (e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors) {
          this.set("errorMessage", e.jqXHR.responseJSON.errors[0]);
        } else {
          this.set("errorMessage", I18n.t("user.invited.invite_link.error"));
        }
        model.setProperties({ saving: false, error: true });
      });
  },

  setDefaultSelectedGroups() {
    this.set("groupIds", []);
  },

  setGroupOptions() {
    Group.findAll().then((groups) => {
      this.set("allGroups", groups.filterBy("automatic", false));
    });
  },
});
