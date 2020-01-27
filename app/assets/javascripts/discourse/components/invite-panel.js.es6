import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import { computed } from "@ember/object";
import { alias, and, equal } from "@ember/object/computed";
import EmberObject from "@ember/object";
import Component from "@ember/component";
import { emailValid } from "discourse/lib/utilities";
import Group from "discourse/models/group";
import Invite from "discourse/models/invite";
import { i18n } from "discourse/lib/computed";
import { getNativeContact } from "discourse/lib/pwa-utils";

export default Component.extend({
  tagName: null,

  inviteModel: alias("panel.model.inviteModel"),
  userInvitedShow: alias("panel.model.userInvitedShow"),

  // If this isn't defined, it will proxy to the user topic on the preferences
  // page which is wrong.
  emailOrUsername: null,
  hasCustomMessage: false,
  customMessage: null,
  inviteIcon: "envelope",
  invitingExistingUserToTopic: false,

  isAdmin: alias("currentUser.admin"),

  willDestroyElement() {
    this._super(...arguments);

    this.reset();
  },

  @discourseComputed(
    "isAdmin",
    "emailOrUsername",
    "invitingToTopic",
    "isPrivateTopic",
    "inviteModel.groupNames.[]",
    "inviteModel.saving",
    "inviteModel.details.can_invite_to"
  )
  disabled(
    isAdmin,
    emailOrUsername,
    invitingToTopic,
    isPrivateTopic,
    groupNames,
    saving,
    can_invite_to
  ) {
    if (saving) return true;
    if (isEmpty(emailOrUsername)) return true;

    const emailTrimmed = emailOrUsername.trim();

    // when inviting to forum, email must be valid
    if (!invitingToTopic && !emailValid(emailTrimmed)) {
      return true;
    }

    // normal users (not admin) can't invite users to private topic via email
    if (!isAdmin && isPrivateTopic && emailValid(emailTrimmed)) {
      return true;
    }

    // when inviting to private topic via email, group name must be specified
    if (isPrivateTopic && isEmpty(groupNames) && emailValid(emailTrimmed)) {
      return true;
    }

    if (can_invite_to) return false;

    return false;
  },

  @discourseComputed(
    "isAdmin",
    "emailOrUsername",
    "inviteModel.saving",
    "isPrivateTopic",
    "inviteModel.groupNames.[]",
    "hasCustomMessage"
  )
  disabledCopyLink(
    isAdmin,
    emailOrUsername,
    saving,
    isPrivateTopic,
    groupNames,
    hasCustomMessage
  ) {
    if (hasCustomMessage) return true;
    if (saving) return true;
    if (isEmpty(emailOrUsername)) return true;

    const email = emailOrUsername.trim();

    // email must be valid
    if (!emailValid(email)) {
      return true;
    }

    // normal users (not admin) can't invite users to private topic via email
    if (!isAdmin && isPrivateTopic && emailValid(email)) {
      return true;
    }

    // when inviting to private topic via email, group name must be specified
    if (isPrivateTopic && isEmpty(groupNames) && emailValid(email)) {
      return true;
    }

    return false;
  },

  @discourseComputed("inviteModel.saving")
  buttonTitle(saving) {
    return saving ? "topic.inviting" : "topic.invite_reply.action";
  },

  // We are inviting to a topic if the topic isn't the current user.
  // The current user would mean we are inviting to the forum in general.
  @discourseComputed("inviteModel")
  invitingToTopic(inviteModel) {
    return inviteModel !== this.currentUser;
  },

  @discourseComputed("inviteModel", "inviteModel.details.can_invite_via_email")
  canInviteViaEmail(inviteModel, canInviteViaEmail) {
    return this.inviteModel === this.currentUser ? true : canInviteViaEmail;
  },

  @discourseComputed("isPM", "canInviteViaEmail")
  showCopyInviteButton(isPM, canInviteViaEmail) {
    return canInviteViaEmail && !isPM;
  },

  topicId: alias("inviteModel.id"),

  // eg: visible only to specific group members
  isPrivateTopic: and(
    "invitingToTopic",
    "inviteModel.category.read_restricted"
  ),

  isPM: equal("inviteModel.archetype", "private_message"),

  // scope to allowed usernames
  allowExistingMembers: alias("invitingToTopic"),

  @discourseComputed("isAdmin", "inviteModel.group_users")
  isGroupOwnerOrAdmin(isAdmin, groupUsers) {
    return (
      isAdmin || (groupUsers && groupUsers.some(groupUser => groupUser.owner))
    );
  },

  // Show Groups? (add invited user to private group)
  @discourseComputed(
    "isGroupOwnerOrAdmin",
    "emailOrUsername",
    "isPrivateTopic",
    "isPM",
    "invitingToTopic",
    "canInviteViaEmail"
  )
  showGroups(
    isGroupOwnerOrAdmin,
    emailOrUsername,
    isPrivateTopic,
    isPM,
    invitingToTopic,
    canInviteViaEmail
  ) {
    return (
      isGroupOwnerOrAdmin &&
      canInviteViaEmail &&
      !isPM &&
      (emailValid(emailOrUsername) || isPrivateTopic || !invitingToTopic)
    );
  },

  showContactPicker: computed(function() {
    return this.capabilities.hasContactPicker;
  }),

  @discourseComputed("emailOrUsername")
  showCustomMessage(emailOrUsername) {
    return this.inviteModel === this.currentUser || emailValid(emailOrUsername);
  },

  // Instructional text for the modal.
  @discourseComputed(
    "isPM",
    "invitingToTopic",
    "emailOrUsername",
    "isPrivateTopic",
    "isAdmin",
    "canInviteViaEmail"
  )
  inviteInstructions(
    isPM,
    invitingToTopic,
    emailOrUsername,
    isPrivateTopic,
    isAdmin,
    canInviteViaEmail
  ) {
    if (!canInviteViaEmail) {
      // can't invite via email, only existing users
      return I18n.t("topic.invite_reply.sso_enabled");
    } else if (isPM) {
      // inviting to a message
      return I18n.t("topic.invite_private.email_or_username");
    } else if (invitingToTopic) {
      // inviting to a private/public topic
      if (isPrivateTopic && !isAdmin) {
        // inviting to a private topic and is not admin
        return I18n.t("topic.invite_reply.to_username");
      } else {
        // when inviting to a topic, display instructions based on provided entity
        if (isEmpty(emailOrUsername)) {
          return I18n.t("topic.invite_reply.to_topic_blank");
        } else if (emailValid(emailOrUsername)) {
          this.set("inviteIcon", "envelope");
          return I18n.t("topic.invite_reply.to_topic_email");
        } else {
          this.set("inviteIcon", "hand-point-right");
          return I18n.t("topic.invite_reply.to_topic_username");
        }
      }
    } else {
      // inviting to forum
      return I18n.t("topic.invite_reply.to_forum");
    }
  },

  @discourseComputed("isPrivateTopic")
  showGroupsClass(isPrivateTopic) {
    return isPrivateTopic ? "required" : "optional";
  },

  groupFinder(term) {
    return Group.findAll({ term, ignore_automatic: true });
  },

  @discourseComputed("isPM", "emailOrUsername", "invitingExistingUserToTopic")
  successMessage(isPM, emailOrUsername, invitingExistingUserToTopic) {
    if (this.hasGroups) {
      return I18n.t("topic.invite_private.success_group");
    } else if (isPM) {
      return I18n.t("topic.invite_private.success");
    } else if (invitingExistingUserToTopic) {
      return I18n.t("topic.invite_reply.success_existing_email", {
        emailOrUsername
      });
    } else if (emailValid(emailOrUsername)) {
      return I18n.t("topic.invite_reply.success_email", { emailOrUsername });
    } else {
      return I18n.t("topic.invite_reply.success_username");
    }
  },

  @discourseComputed("isPM")
  errorMessage(isPM) {
    return isPM
      ? I18n.t("topic.invite_private.error")
      : I18n.t("topic.invite_reply.error");
  },

  @discourseComputed("canInviteViaEmail")
  placeholderKey(canInviteViaEmail) {
    return canInviteViaEmail
      ? "topic.invite_private.email_or_username_placeholder"
      : "topic.invite_reply.username_placeholder";
  },

  customMessagePlaceholder: i18n("invite.custom_message_placeholder"),

  // Reset the modal to allow a new user to be invited.
  reset() {
    this.setProperties({
      emailOrUsername: null,
      hasCustomMessage: false,
      customMessage: null,
      invitingExistingUserToTopic: false
    });

    this.inviteModel.setProperties({
      groupNames: null,
      error: false,
      saving: false,
      finished: false,
      inviteLink: null
    });
  },

  actions: {
    createInvite() {
      if (this.disabled) {
        return;
      }

      const groupNames = this.get("inviteModel.groupNames");
      const userInvitedController = this.userInvitedShow;

      const model = this.inviteModel;
      model.setProperties({ saving: true, error: false });

      const onerror = e => {
        if (e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors) {
          this.set("errorMessage", e.jqXHR.responseJSON.errors[0]);
        } else {
          this.set(
            "errorMessage",
            this.isPM
              ? I18n.t("topic.invite_private.error")
              : I18n.t("topic.invite_reply.error")
          );
        }
        model.setProperties({ saving: false, error: true });
      };

      if (this.hasGroups) {
        return this.inviteModel
          .createGroupInvite(this.emailOrUsername.trim())
          .then(data => {
            model.setProperties({ saving: false, finished: true });
            this.get("inviteModel.details.allowed_groups").pushObject(
              EmberObject.create(data.group)
            );
            this.appEvents.trigger("post-stream:refresh");
          })
          .catch(onerror);
      } else {
        return this.inviteModel
          .createInvite(
            this.emailOrUsername.trim(),
            groupNames,
            this.customMessage
          )
          .then(result => {
            model.setProperties({ saving: false, finished: true });
            if (!this.invitingToTopic && userInvitedController) {
              Invite.findInvitedBy(
                this.currentUser,
                userInvitedController.get("filter")
              ).then(inviteModel => {
                userInvitedController.setProperties({
                  model: inviteModel,
                  totalInvites: inviteModel.invites.length
                });
              });
            } else if (this.isPM && result && result.user) {
              this.get("inviteModel.details.allowed_users").pushObject(
                EmberObject.create(result.user)
              );
              this.appEvents.trigger("post-stream:refresh");
            } else if (
              this.invitingToTopic &&
              emailValid(this.emailOrUsername.trim()) &&
              result &&
              result.user
            ) {
              this.set("invitingExistingUserToTopic", true);
            }
          })
          .catch(onerror);
      }
    },

    generateInvitelink() {
      if (this.disabled) {
        return;
      }

      const groupNames = this.get("inviteModel.groupNames");
      const userInvitedController = this.userInvitedShow;
      const model = this.inviteModel;
      model.setProperties({ saving: true, error: false });

      let topicId;
      if (this.invitingToTopic) {
        topicId = this.get("inviteModel.id");
      }

      return model
        .generateInviteLink(this.emailOrUsername.trim(), groupNames, topicId)
        .then(result => {
          model.setProperties({
            saving: false,
            finished: true,
            inviteLink: result
          });

          if (userInvitedController) {
            Invite.findInvitedBy(
              this.currentUser,
              userInvitedController.get("filter")
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
            this.set(
              "errorMessage",
              this.isPM
                ? I18n.t("topic.invite_private.error")
                : I18n.t("topic.invite_reply.error")
            );
          }
          model.setProperties({ saving: false, error: true });
        });
    },

    showCustomMessageBox() {
      this.toggleProperty("hasCustomMessage");
      if (this.hasCustomMessage) {
        if (this.inviteModel === this.currentUser) {
          this.set(
            "customMessage",
            I18n.t("invite.custom_message_template_forum")
          );
        } else {
          this.set(
            "customMessage",
            I18n.t("invite.custom_message_template_topic")
          );
        }
      } else {
        this.set("customMessage", null);
      }
    },

    searchContact() {
      getNativeContact(["email"], false).then(result => {
        this.set("emailOrUsername", result[0].email[0]);
      });
    }
  }
});
