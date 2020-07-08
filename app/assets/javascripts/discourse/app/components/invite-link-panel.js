import I18n from "I18n";
import Component from "@ember/component";
import Group from "discourse/models/group";
import { readOnly } from "@ember/object/computed";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import Invite from "discourse/models/invite";

export default Component.extend({
  inviteModel: readOnly("panel.model.inviteModel"),
  userInvitedShow: readOnly("panel.model.userInvitedShow"),
  isStaff: readOnly("currentUser.staff"),
  maxRedemptionAllowed: 5,
  inviteExpiresAt: moment()
    .add(1, "month")
    .format("YYYY-MM-DD"),
  groupIds: null,
  allGroups: null,

  init() {
    this._super(...arguments);

    Group.findAll().then(groups => {
      this.set("allGroups", groups.filterBy("automatic", false));
    });
  },

  willDestroyElement() {
    this._super(...arguments);

    this.reset();
  },

  @discourseComputed("isStaff", "inviteModel.saving", "maxRedemptionAllowed")
  disabled(isStaff, saving, canInviteTo, maxRedemptionAllowed) {
    if (saving) return true;
    if (!isStaff) return true;
    if (maxRedemptionAllowed < 2) return true;

    return false;
  },

  groupFinder(term) {
    return Group.findAll({ term, ignore_automatic: true });
  },

  errorMessage: I18n.t("user.invited.invite_link.error"),

  reset() {
    this.setProperties({
      maxRedemptionAllowed: 5,
      groupIds: null
    });

    this.inviteModel.setProperties({
      error: false,
      saving: false,
      finished: false,
      inviteLink: null
    });
  },

  @action
  generateMultipleUseInviteLink() {
    if (this.disabled) {
      return;
    }

    const groupNames = this.allGroups
      .filter(g => this.groupIds.includes(g.id))
      .map(g => g.name);
    const maxRedemptionAllowed = this.maxRedemptionAllowed;
    const inviteExpiresAt = this.inviteExpiresAt;
    const userInvitedController = this.userInvitedShow;
    const model = this.inviteModel;
    model.setProperties({ saving: true, error: false });

    return model
      .generateMultipleUseInviteLink(
        groupNames,
        maxRedemptionAllowed,
        inviteExpiresAt
      )
      .then(result => {
        model.setProperties({
          saving: false,
          finished: true,
          inviteLink: result
        });

        if (userInvitedController) {
          Invite.findInvitedBy(
            this.currentUser,
            userInvitedController.filter
          ).then(inviteModel => {
            userInvitedController.setProperties({
              model: inviteModel,
              totalInvites: inviteModel.invites.length
            });
          });
        }
      })
      .catch(e => {
        if (e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors) {
          this.set("errorMessage", e.jqXHR.responseJSON.errors[0]);
        } else {
          this.set("errorMessage", I18n.t("user.invited.invite_link.error"));
        }
        model.setProperties({ saving: false, error: true });
      });
  }
});
