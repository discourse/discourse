import ModalFunctionality from "discourse/mixins/modal-functionality";
import { emailValid } from "discourse/lib/utilities";
import computed from "ember-addons/ember-computed-decorators";
import Group from "discourse/models/group";
import Invite from "discourse/models/invite";

export default Ember.Controller.extend(ModalFunctionality, {
  userInvitedShow: Ember.inject.controller("user-invited-show"),

  // If this isn't defined, it will proxy to the user model on the preferences
  // page which is wrong.
  emailOrUsername: null,
  hasCustomMessage: false,
  customMessage: null,
  inviteIcon: "envelope",
  invitingExistingUserToTopic: false,

  @computed("isMessage", "invitingToTopic")
  title(isMessage, invitingToTopic) {
    if (isMessage) {
      return "topic.invite_private.title";
    } else if (invitingToTopic) {
      return "topic.invite_reply.title";
    } else {
      return "user.invited.create";
    }
  },

  @computed
  isAdmin() {
    return this.currentUser.admin;
  },

  @computed(
    "isAdmin",
    "emailOrUsername",
    "invitingToTopic",
    "isPrivateTopic",
    "model.groupNames",
    "model.saving",
    "model.details.can_invite_to"
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
    if (Ember.isEmpty(emailOrUsername)) return true;
    const emailTrimmed = emailOrUsername.trim();

    // when inviting to forum, email must be valid
    if (!invitingToTopic && !emailValid(emailTrimmed)) return true;
    // normal users (not admin) can't invite users to private topic via email
    if (!isAdmin && isPrivateTopic && emailValid(emailTrimmed)) return true;
    // when inviting to private topic via email, group name must be specified
    if (isPrivateTopic && Ember.isEmpty(groupNames) && emailValid(emailTrimmed))
      return true;

    if (can_invite_to) return false;
    return false;
  },

  @computed(
    "isAdmin",
    "emailOrUsername",
    "model.saving",
    "isPrivateTopic",
    "model.groupNames",
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
    if (Ember.isEmpty(emailOrUsername)) return true;
    const email = emailOrUsername.trim();
    // email must be valid
    if (!emailValid(email)) return true;
    // normal users (not admin) can't invite users to private topic via email
    if (!isAdmin && isPrivateTopic && emailValid(email)) return true;
    // when inviting to private topic via email, group name must be specified
    if (isPrivateTopic && Ember.isEmpty(groupNames) && emailValid(email))
      return true;
    return false;
  },

  @computed("model.saving")
  buttonTitle(saving) {
    return saving ? "topic.inviting" : "topic.invite_reply.action";
  },

  // We are inviting to a topic if the model isn't the current user.
  // The current user would mean we are inviting to the forum in general.
  @computed("model")
  invitingToTopic(model) {
    return model !== this.currentUser;
  },

  @computed("model", "model.details.can_invite_via_email")
  canInviteViaEmail(model, can_invite_via_email) {
    return this.get("model") === this.currentUser ? true : can_invite_via_email;
  },

  @computed("isMessage", "canInviteViaEmail")
  showCopyInviteButton(isMessage, canInviteViaEmail) {
    return canInviteViaEmail && !isMessage;
  },

  topicId: Ember.computed.alias("model.id"),

  // Is Private Topic? (i.e. visible only to specific group members)
  isPrivateTopic: Em.computed.and(
    "invitingToTopic",
    "model.category.read_restricted"
  ),

  // Is Private Message?
  isMessage: Em.computed.equal("model.archetype", "private_message"),

  // Allow Existing Members? (username autocomplete)
  allowExistingMembers: Ember.computed.alias("invitingToTopic"),

  @computed("isAdmin", "model.group_users")
  isGroupOwnerOrAdmin(isAdmin, groupUsers) {
    return (
      isAdmin || (groupUsers && groupUsers.some(groupUser => groupUser.owner))
    );
  },

  // Show Groups? (add invited user to private group)
  @computed(
    "isGroupOwnerOrAdmin",
    "emailOrUsername",
    "isPrivateTopic",
    "isMessage",
    "invitingToTopic",
    "canInviteViaEmail"
  )
  showGroups(
    isGroupOwnerOrAdmin,
    emailOrUsername,
    isPrivateTopic,
    isMessage,
    invitingToTopic,
    canInviteViaEmail
  ) {
    return (
      isGroupOwnerOrAdmin &&
      canInviteViaEmail &&
      !isMessage &&
      (emailValid(emailOrUsername) || isPrivateTopic || !invitingToTopic)
    );
  },

  @computed("emailOrUsername")
  showCustomMessage(emailOrUsername) {
    return (
      this.get("model") === this.currentUser || emailValid(emailOrUsername)
    );
  },

  // Instructional text for the modal.
  @computed(
    "isMessage",
    "invitingToTopic",
    "emailOrUsername",
    "isPrivateTopic",
    "isAdmin",
    "canInviteViaEmail"
  )
  inviteInstructions(
    isMessage,
    invitingToTopic,
    emailOrUsername,
    isPrivateTopic,
    isAdmin,
    canInviteViaEmail
  ) {
    if (!canInviteViaEmail) {
      // can't invite via email, only existing users
      return I18n.t("topic.invite_reply.sso_enabled");
    } else if (isMessage) {
      // inviting to a message
      return I18n.t("topic.invite_private.email_or_username");
    } else if (invitingToTopic) {
      // inviting to a private/public topic
      if (isPrivateTopic && !isAdmin) {
        // inviting to a private topic and is not admin
        return I18n.t("topic.invite_reply.to_username");
      } else {
        // when inviting to a topic, display instructions based on provided entity
        if (Ember.isEmpty(emailOrUsername)) {
          return I18n.t("topic.invite_reply.to_topic_blank");
        } else if (emailValid(emailOrUsername)) {
          this.set("inviteIcon", "envelope");
          return I18n.t("topic.invite_reply.to_topic_email");
        } else {
          this.set("inviteIcon", "hand-o-right");
          return I18n.t("topic.invite_reply.to_topic_username");
        }
      }
    } else {
      // inviting to forum
      return I18n.t("topic.invite_reply.to_forum");
    }
  },

  @computed("isPrivateTopic")
  showGroupsClass(isPrivateTopic) {
    return isPrivateTopic ? "required" : "optional";
  },

  groupFinder(term) {
    return Group.findAll({ term: term, ignore_automatic: true });
  },

  @computed("isPrivateTopic", "isMessage")
  includeMentionableGroups(isPrivateTopic, isMessage) {
    return !isPrivateTopic && !isMessage;
  },

  @computed("isMessage", "emailOrUsername", "invitingExistingUserToTopic")
  successMessage(isMessage, emailOrUsername, invitingExistingUserToTopic) {
    if (this.get("hasGroups")) {
      return I18n.t("topic.invite_private.success_group");
    } else if (isMessage) {
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

  @computed("isMessage")
  errorMessage(isMessage) {
    return isMessage
      ? I18n.t("topic.invite_private.error")
      : I18n.t("topic.invite_reply.error");
  },

  @computed("canInviteViaEmail")
  placeholderKey(canInviteViaEmail) {
    return canInviteViaEmail
      ? "topic.invite_private.email_or_username_placeholder"
      : "topic.invite_reply.username_placeholder";
  },

  @computed
  customMessagePlaceholder() {
    return I18n.t("invite.custom_message_placeholder");
  },

  // Reset the modal to allow a new user to be invited.
  reset() {
    this.set("emailOrUsername", null);
    this.set("hasCustomMessage", false);
    this.set("customMessage", null);
    this.set("invitingExistingUserToTopic", false);
    this.get("model").setProperties({
      groupNames: null,
      error: false,
      saving: false,
      finished: false,
      inviteLink: null
    });
  },

  actions: {
    createInvite() {
      const self = this;
      if (this.get("disabled")) {
        return;
      }

      const groupNames = this.get("model.groupNames"),
        userInvitedController = this.get("userInvitedShow"),
        model = this.get("model");

      model.setProperties({ saving: true, error: false });

      const onerror = function(e) {
        if (e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors) {
          self.set("errorMessage", e.jqXHR.responseJSON.errors[0]);
        } else {
          self.set(
            "errorMessage",
            self.get("isMessage")
              ? I18n.t("topic.invite_private.error")
              : I18n.t("topic.invite_reply.error")
          );
        }
        model.setProperties({ saving: false, error: true });
      };

      if (this.get("hasGroups")) {
        return this.get("model")
          .createGroupInvite(this.get("emailOrUsername").trim())
          .then(data => {
            model.setProperties({ saving: false, finished: true });
            this.get("model.details.allowed_groups").pushObject(
              Ember.Object.create(data.group)
            );
            this.appEvents.trigger("post-stream:refresh");
          })
          .catch(onerror);
      } else {
        return this.get("model")
          .createInvite(
            this.get("emailOrUsername").trim(),
            groupNames,
            this.get("customMessage")
          )
          .then(result => {
            model.setProperties({ saving: false, finished: true });
            if (!this.get("invitingToTopic")) {
              Invite.findInvitedBy(
                this.currentUser,
                userInvitedController.get("filter")
              ).then(invite_model => {
                userInvitedController.set("model", invite_model);
                userInvitedController.set(
                  "totalInvites",
                  invite_model.invites.length
                );
              });
            } else if (this.get("isMessage") && result && result.user) {
              this.get("model.details.allowed_users").pushObject(
                Ember.Object.create(result.user)
              );
              this.appEvents.trigger("post-stream:refresh");
            } else if (
              this.get("invitingToTopic") &&
              emailValid(this.get("emailOrUsername").trim()) &&
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
      const self = this;

      if (this.get("disabled")) {
        return;
      }

      const groupNames = this.get("model.groupNames"),
        userInvitedController = this.get("userInvitedShow"),
        model = this.get("model");

      var topicId = null;
      if (this.get("invitingToTopic")) {
        topicId = this.get("model.id");
      }

      model.setProperties({ saving: true, error: false });

      return this.get("model")
        .generateInviteLink(
          this.get("emailOrUsername").trim(),
          groupNames,
          topicId
        )
        .then(result => {
          model.setProperties({
            saving: false,
            finished: true,
            inviteLink: result
          });
          Invite.findInvitedBy(
            this.currentUser,
            userInvitedController.get("filter")
          ).then(invite_model => {
            userInvitedController.set("model", invite_model);
            userInvitedController.set(
              "totalInvites",
              invite_model.invites.length
            );
          });
        })
        .catch(function(e) {
          if (e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors) {
            self.set("errorMessage", e.jqXHR.responseJSON.errors[0]);
          } else {
            self.set(
              "errorMessage",
              self.get("isMessage")
                ? I18n.t("topic.invite_private.error")
                : I18n.t("topic.invite_reply.error")
            );
          }
          model.setProperties({ saving: false, error: true });
        });
    },

    showCustomMessageBox() {
      this.toggleProperty("hasCustomMessage");
      if (this.get("hasCustomMessage")) {
        if (this.get("model") === this.currentUser) {
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
    }
  }
});
