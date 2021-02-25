import Controller from "@ember/controller";
import { action } from "@ember/object";
import { equal } from "@ember/object/computed";
import { getAbsoluteURL } from "discourse-common/lib/get-url";
import discourseComputed from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import copyText from "discourse/lib/copy-text";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import Group from "discourse/models/group";
import I18n from "I18n";

export default Controller.extend(ModalFunctionality, {
  allGroups: null,

  showAdvanced: false,
  showOnly: false,
  type: "link",
  inviteId: null,
  inviteKey: null,
  link: "",
  email: "",
  maxRedemptionsAllowed: 1,
  message: "",
  topicId: null,
  topicTitle: null,
  groupIds: null,
  expiresAt: "",

  onShow() {
    Group.findAll().then((groups) => {
      this.set("allGroups", groups.filterBy("automatic", false));
    });

    let inviteKey = "";
    for (let i = 0; i < 32; ++i) {
      inviteKey += "0123456789abcdef"[Math.floor(Math.random() * 16)];
    }

    this.setProperties({
      showAdvanced: false,
      showOnly: false,
      type: "link",
      inviteId: null,
      inviteKey,
      link: getAbsoluteURL(`/invites/${inviteKey}`),
      email: "",
      maxRedemptionsAllowed: 1,
      message: "",
      topicId: null,
      topicTitle: null,
      groupIds: [],
      expiresAt: moment().add(1, "week").format("YYYY-MM-DD HH:mmZ"),
    });
  },

  setInvite(invite) {
    const email = invite.email || this.email;

    this.setProperties({
      error: null,
      type: email ? "email" : "link",
      inviteId: invite.id,
      link: invite.link,
      email,
      maxRedemptionsAllowed: invite.max_redemptions_allowed,
      message: invite.custom_message,
      groupIds: invite.groups && invite.groups.map((g) => g.id),
      expiresAt: invite.expires_at,
    });

    if (invite.topics && invite.topics.length > 0) {
      this.setProperties({
        topicId: invite.topics[0].id,
        topicTitle: invite.topics[0].title,
      });
    }
  },

  isLink: equal("type", "link"),
  isEmail: equal("type", "email"),

  @discourseComputed("expiresAt")
  expiresAtRelative(expiresAt) {
    return moment.duration(moment(expiresAt) - moment()).humanize();
  },

  @discourseComputed("type", "email")
  disabled(type, email) {
    if (type === "email") {
      return !email;
    }

    return false;
  },

  @discourseComputed("type", "inviteId")
  saveLabel(type, inviteId) {
    if (inviteId) {
      return "user.invited.invite.update_invite";
    } else if (type === "link") {
      return "user.invited.invite.create_invite_link";
    } else if (type === "email") {
      return "user.invited.invite.send_invite_email";
    }
  },

  @action
  copyLink(invite) {
    const $copyRange = $('<p id="copy-range"></p>');
    $copyRange.html(invite.trim());
    $(document.body).append($copyRange);
    copyText(invite, $copyRange[0]);
    $copyRange.remove();
  },

  @action
  saveInvite() {
    this.appEvents.trigger("modal-body:clearFlash");

    const data = {
      group_ids: this.groupIds,
      topic_id: this.topicId,
      expires_at: this.expiresAt,
    };

    if (!this.inviteId) {
      data.invite_key = this.inviteKey;
    }

    if (this.type === "link") {
      data.max_redemptions_allowed = this.maxRedemptionsAllowed;
    } else if (this.type === "email") {
      data.email = this.email;
      data.message = this.message;
    }

    const promise = this.inviteId
      ? ajax(`/invites/${this.inviteId}`, { type: "PUT", data })
      : ajax("/invites", { type: "POST", data }).then((result) =>
          this.setInvite(result.invite)
        );

    promise
      .then(() => {
        this.appEvents.trigger("modal-body:flash", {
          text: I18n.t("user.invited.invite.invite_saved"),
          messageClass: "success",
        });
      })
      .catch((e) =>
        this.appEvents.trigger("modal-body:flash", {
          text: extractError(e),
          messageClass: "error",
        })
      );
  },
});
