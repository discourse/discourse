import Component, { Textarea } from "@ember/component";
import { fn, hash } from "@ember/helper";
import EmberObject, { action } from "@ember/object";
import { alias, and, equal, readOnly } from "@ember/object/computed";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import DButton from "discourse/components/d-button";
import DiscourseLinkedText from "discourse/components/discourse-linked-text";
import GeneratedInviteLink from "discourse/components/generated-invite-link";
import TextField from "discourse/components/text-field";
import htmlSafe from "discourse/helpers/html-safe";
import { computedI18n } from "discourse/lib/computed";
import discourseComputed from "discourse/lib/decorators";
import { getNativeContact } from "discourse/lib/pwa-utils";
import { emailValid } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";
import GroupChooser from "select-kit/components/group-chooser";

export default class InvitePanel extends Component {
  @service site;

  @readOnly("currentUser.staff") isStaff;
  @readOnly("currentUser.admin") isAdmin;
  @alias("inviteModel.id") topicId;
  @equal("inviteModel.archetype", "private_message") isPM;
  @and("isStaff", "siteSettings.must_approve_users") showApprovalMessage;

  // eg: visible only to specific group members
  @and("invitingToTopic", "inviteModel.category.read_restricted")
  isPrivateTopic;

  // scope to allowed usernames
  @alias("invitingToTopic") allowExistingMembers;

  @computedI18n("invite.custom_message_placeholder") customMessagePlaceholder;

  groupIds = null;
  allGroups = null;

  // invitee is either a user, group or email
  invitee = null;

  isInviteeGroup = false;
  hasCustomMessage = false;
  customMessage = null;
  inviteIcon = "envelope";
  invitingExistingUserToTopic = false;

  init() {
    super.init(...arguments);
    this.setDefaultSelectedGroups();
    this.setGroupOptions();
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    this.reset();
  }

  @discourseComputed(
    "isAdmin",
    "invitee",
    "invitingToTopic",
    "isPrivateTopic",
    "groupIds",
    "inviteModel.saving",
    "inviteModel.details.can_invite_to"
  )
  disabled(
    isAdmin,
    invitee,
    invitingToTopic,
    isPrivateTopic,
    groupIds,
    saving,
    can_invite_to
  ) {
    if (saving) {
      return true;
    }
    if (isEmpty(invitee)) {
      return true;
    }

    // when inviting to forum, email must be valid
    if (!invitingToTopic && !emailValid(invitee)) {
      return true;
    }

    // normal users (not admin) can't invite users to private topic via email
    if (!isAdmin && isPrivateTopic && emailValid(invitee)) {
      return true;
    }

    // when inviting to private topic via email, group name must be specified
    if (isPrivateTopic && isEmpty(groupIds) && emailValid(invitee)) {
      return true;
    }

    if (can_invite_to) {
      return false;
    }

    return false;
  }

  @discourseComputed(
    "isAdmin",
    "invitee",
    "inviteModel.saving",
    "isPrivateTopic",
    "groupIds",
    "hasCustomMessage"
  )
  disabledCopyLink(
    isAdmin,
    invitee,
    saving,
    isPrivateTopic,
    groupIds,
    hasCustomMessage
  ) {
    if (hasCustomMessage) {
      return true;
    }
    if (saving) {
      return true;
    }
    if (isEmpty(invitee)) {
      return true;
    }

    // email must be valid
    if (!emailValid(invitee)) {
      return true;
    }

    // normal users (not admin) can't invite users to private topic via email
    if (!isAdmin && isPrivateTopic && emailValid(invitee)) {
      return true;
    }

    // when inviting to private topic via email, group name must be specified
    if (isPrivateTopic && isEmpty(groupIds) && emailValid(invitee)) {
      return true;
    }

    return false;
  }

  @discourseComputed("inviteModel.saving")
  buttonTitle(saving) {
    return saving ? "topic.inviting" : "topic.invite_reply.action";
  }

  // We are inviting to a topic if the topic isn't the current user.
  // The current user would mean we are inviting to the forum in general.
  @discourseComputed("inviteModel")
  invitingToTopic(inviteModel) {
    return inviteModel !== this.currentUser;
  }

  @discourseComputed("inviteModel", "inviteModel.details.can_invite_via_email")
  canInviteViaEmail(inviteModel, canInviteViaEmail) {
    return inviteModel === this.currentUser ? true : canInviteViaEmail;
  }

  @discourseComputed("isPM", "canInviteViaEmail")
  showCopyInviteButton(isPM, canInviteViaEmail) {
    return canInviteViaEmail && !isPM;
  }

  @discourseComputed("isAdmin", "inviteModel.group_users")
  isGroupOwnerOrAdmin(isAdmin, groupUsers) {
    return (
      isAdmin || (groupUsers && groupUsers.some((groupUser) => groupUser.owner))
    );
  }

  // Show Groups? (add invited user to private group)
  @discourseComputed(
    "isGroupOwnerOrAdmin",
    "invitee",
    "isPrivateTopic",
    "isPM",
    "invitingToTopic",
    "canInviteViaEmail"
  )
  showGroups(
    isGroupOwnerOrAdmin,
    invitee,
    isPrivateTopic,
    isPM,
    invitingToTopic,
    canInviteViaEmail
  ) {
    return (
      isGroupOwnerOrAdmin &&
      canInviteViaEmail &&
      !isPM &&
      (emailValid(invitee) || isPrivateTopic || !invitingToTopic)
    );
  }

  @discourseComputed("invitee")
  showCustomMessage(invitee) {
    return this.inviteModel === this.currentUser || emailValid(invitee);
  }

  // Instructional text for the modal.
  @discourseComputed(
    "isPM",
    "invitingToTopic",
    "invitee",
    "isPrivateTopic",
    "isAdmin",
    "canInviteViaEmail"
  )
  inviteInstructions(
    isPM,
    invitingToTopic,
    invitee,
    isPrivateTopic,
    isAdmin,
    canInviteViaEmail
  ) {
    if (!canInviteViaEmail) {
      // can't invite via email, only existing users
      return i18n("topic.invite_reply.discourse_connect_enabled");
    } else if (isPM) {
      // inviting to a message
      return i18n("topic.invite_private.email_or_username");
    } else if (invitingToTopic) {
      // inviting to a private/public topic
      if (isPrivateTopic && !isAdmin) {
        // inviting to a private topic and is not admin
        return i18n("topic.invite_reply.to_username");
      } else {
        // when inviting to a topic, display instructions based on provided entity
        if (isEmpty(invitee)) {
          return i18n("topic.invite_reply.to_topic_blank");
        } else if (emailValid(invitee)) {
          this.set("inviteIcon", "envelope");
          return i18n("topic.invite_reply.to_topic_email");
        } else {
          this.set("inviteIcon", "hand-point-right");
          return i18n("topic.invite_reply.to_topic_username");
        }
      }
    } else {
      // inviting to forum
      return i18n("topic.invite_reply.to_forum");
    }
  }

  @discourseComputed("isPrivateTopic")
  showGroupsClass(isPrivateTopic) {
    return isPrivateTopic ? "required" : "optional";
  }

  @discourseComputed("isPM", "invitee", "invitingExistingUserToTopic")
  successMessage(isPM, invitee, invitingExistingUserToTopic) {
    if (this.isInviteeGroup) {
      return i18n("topic.invite_private.success_group");
    } else if (isPM) {
      return i18n("topic.invite_private.success");
    } else if (invitingExistingUserToTopic) {
      return i18n("topic.invite_reply.success_existing_email", {
        invitee,
      });
    } else if (emailValid(invitee)) {
      return i18n("topic.invite_reply.success_email", { invitee });
    } else {
      return i18n("topic.invite_reply.success_username");
    }
  }

  @discourseComputed("isPM", "ajaxError")
  errorMessage(isPM, ajaxError) {
    if (ajaxError) {
      return ajaxError;
    }
    return isPM
      ? i18n("topic.invite_private.error")
      : i18n("topic.invite_reply.error");
  }

  @discourseComputed("canInviteViaEmail")
  placeholderKey(canInviteViaEmail) {
    return canInviteViaEmail
      ? "topic.invite_private.email_or_username_placeholder"
      : "topic.invite_reply.username_placeholder";
  }

  // Reset the modal to allow a new user to be invited.
  reset() {
    this.setProperties({
      invitee: null,
      isInviteeGroup: false,
      hasCustomMessage: false,
      customMessage: null,
      invitingExistingUserToTopic: false,
      groupIds: [],
    });

    this.inviteModel.setProperties({
      error: false,
      saving: false,
      finished: false,
      inviteLink: null,
    });
  }

  setDefaultSelectedGroups() {
    this.set("groupIds", []);
  }

  setGroupOptions() {
    this.set(
      "allGroups",
      this.site.groups.filter((g) => !g.automatic)
    );
  }

  @action
  createInvite() {
    if (this.disabled) {
      return;
    }

    const groupIds = this.groupIds;
    const model = this.inviteModel;
    model.setProperties({ saving: true, error: false });

    const onerror = (e) => {
      if (e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors) {
        this.set("ajaxError", e.jqXHR.responseJSON.errors[0]);
      } else {
        this.set("ajaxError", null);
      }
      model.setProperties({ saving: false, error: true });
    };

    if (this.isInviteeGroup) {
      return this.inviteModel
        .createGroupInvite(this.invitee.trim())
        .then(() => {
          model.setProperties({ saving: false, finished: true });
          this.inviteModel.reload().then(() => {
            // TODO (glimmer-post-stream) the Glimmer Post Stream does not listen to this event
            this.appEvents.trigger("post-stream:refresh");
          });
        })
        .catch(onerror);
    } else {
      return this.inviteModel
        .createInvite(this.invitee.trim(), groupIds, this.customMessage)
        .then((result) => {
          model.setProperties({ saving: false, finished: true });
          if (this.isPM && result && result.user) {
            this.get("inviteModel.details.allowed_users").pushObject(
              EmberObject.create(result.user)
            );
            // TODO (glimmer-post-stream) the Glimmer Post Stream does not listen to this event
            this.appEvents.trigger("post-stream:refresh", { force: true });
          } else if (
            this.invitingToTopic &&
            emailValid(this.invitee.trim()) &&
            result &&
            result.user
          ) {
            this.set("invitingExistingUserToTopic", true);
          }
        })
        .catch(onerror);
    }
  }

  @action
  generateInviteLink() {
    if (this.disabled) {
      return;
    }

    const groupIds = this.groupIds;
    const model = this.inviteModel;
    model.setProperties({ saving: true, error: false });

    let topicId;
    if (this.invitingToTopic) {
      topicId = this.get("inviteModel.id");
    }

    return model
      .generateInviteLink(this.invitee.trim(), groupIds, topicId)
      .then((result) => {
        model.setProperties({
          saving: false,
          finished: true,
          inviteLink: result.link,
        });
      })
      .catch((e) => {
        if (e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors) {
          this.set("ajaxError", e.jqXHR.responseJSON.errors[0]);
        } else {
          this.set("ajaxError", null);
        }
        model.setProperties({ saving: false, error: true });
      });
  }

  @action
  showCustomMessageBox() {
    this.toggleProperty("hasCustomMessage");
    if (this.hasCustomMessage) {
      if (this.inviteModel === this.currentUser) {
        this.set("customMessage", i18n("invite.custom_message_template_forum"));
      } else {
        this.set("customMessage", i18n("invite.custom_message_template_topic"));
      }
    } else {
      this.set("customMessage", null);
    }
  }

  @action
  searchContact() {
    getNativeContact(this.capabilities, ["email"], false).then((result) => {
      this.set("invitee", result[0].email[0]);
    });
  }

  @action
  updateInvitee(selected, content) {
    let invitee = content.findBy("id", selected[0]);
    if (!invitee && content.length) {
      invitee =
        typeof content[0] === "string" ? { id: content[0] } : content[0];
    }
    if (invitee) {
      this.setProperties({
        invitee: invitee.id.trim(),
        isInviteeGroup: invitee.isGroup || false,
      });
    } else {
      this.setProperties({
        invitee: null,
        isInviteeGroup: false,
      });
    }
  }

  <template>
    {{#if this.inviteModel.error}}
      <div class="alert alert-error">
        {{htmlSafe this.errorMessage}}
      </div>
    {{/if}}

    <div class="body">
      {{#if this.inviteModel.finished}}
        {{#if this.inviteModel.inviteLink}}
          <GeneratedInviteLink
            @link={{this.inviteModel.inviteLink}}
            @email={{this.invitee}}
          />
        {{else}}
          <div class="success-message">
            {{htmlSafe this.successMessage}}
          </div>
        {{/if}}
      {{else}}
        <div class="invite-user-control">
          <label class="instructions">{{this.inviteInstructions}}</label>
          <div class="invite-user-input-wrapper">
            {{#if this.allowExistingMembers}}
              <EmailGroupUserChooser
                @value={{this.invitee}}
                @onChange={{this.updateInvitee}}
                @options={{hash
                  maximum=1
                  allowEmails=this.canInviteViaEmail
                  excludeCurrentUser=true
                  includeMessageableGroups=this.isPM
                  filterPlaceholder=this.placeholderKey
                  fullWidthWrap=true
                }}
                class="invite-user-input"
              />
            {{else}}
              <TextField
                @value={{this.invitee}}
                @placeholderKey="topic.invite_reply.email_placeholder"
                class="email-or-username-input"
              />
            {{/if}}
            {{#if this.capabilities.hasContactPicker}}
              <DButton
                @icon="address-book"
                @action={{this.searchContact}}
                class="btn-primary open-contact-picker"
              />
            {{/if}}
          </div>
        </div>

        {{#if this.showGroups}}
          <div class="group-access-control">
            <label class="instructions {{this.showGroupsClass}}">
              {{i18n "topic.automatically_add_to_groups"}}
            </label>
            <GroupChooser
              @content={{this.allGroups}}
              @value={{this.groupIds}}
              @labelProperty="name"
              @onChange={{fn (mut this.groupIds)}}
            />
          </div>
        {{/if}}

        {{#if this.showCustomMessage}}
          <div class="show-custom-message-control">
            <label class="instructions">
              <DiscourseLinkedText
                @action={{this.showCustomMessageBox}}
                @text="invite.custom_message"
                class="optional"
              />
            </label>
            {{#if this.hasCustomMessage}}
              <Textarea
                @value={{this.customMessage}}
                placeholder={{this.customMessagePlaceholder}}
              />
            {{/if}}
          </div>
        {{/if}}
      {{/if}}

      {{#if this.showApprovalMessage}}
        <label class="instructions approval-notice">
          {{i18n "invite.approval_not_required"}}
        </label>
      {{/if}}
    </div>

    <div class="footer">
      {{#if this.inviteModel.finished}}
        <DButton @action={{@closeModal}} @label="close" class="btn-primary" />
      {{else}}
        <DButton
          @icon={{this.inviteIcon}}
          @action={{this.createInvite}}
          @disabled={{this.disabled}}
          @label={{this.buttonTitle}}
          class="btn-primary send-invite"
        />
        {{#if this.showCopyInviteButton}}
          <DButton
            @icon="link"
            @action={{this.generateInviteLink}}
            @disabled={{this.disabledCopyLink}}
            @label="user.invited.generate_link"
            class="btn-primary generate-invite-link"
          />
        {{/if}}
      {{/if}}
    </div>
  </template>
}
