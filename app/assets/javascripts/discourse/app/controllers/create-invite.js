import Controller from "@ember/controller";
import { action } from "@ember/object";
import { getAbsoluteURL } from "discourse-common/lib/get-url";
import discourseComputed from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";
import copyText from "discourse/lib/copy-text";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import Group from "discourse/models/group";

export default Controller.extend(ModalFunctionality, {
  onShow() {
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
      groupIds: [],
      expiresAt: moment().add(1, "week").format("YYYY-MM-DD HH:mmZ"),
    });

    Group.findAll().then((groups) => {
      this.set("allGroups", groups.filterBy("automatic", false));
    });
  },

  setInvite(invite) {
    this.setProperties({
      type: invite.email ? "email" : "link",
      inviteId: invite.id,
      link: invite.link,
      email: invite.email,
      maxRedemptionsAllowed: invite.max_redemptions_allowed,
      message: invite.custom_message,
      topicId: invite.topics && invite.topics.length > 0 && invite.topics[0].id,
      topicTitle:
        invite.topics && invite.topics.length > 0 && invite.topics[0].title,
      groupIds: invite.groups && invite.groups.map((g) => g.id),
      expiresAt: invite.expires_at,
    });
  },

  @discourseComputed("expiresAt")
  expiresAtRelative(expiresAt) {
    return moment.duration(moment(expiresAt) - moment()).humanize();
  },

  @discourseComputed("type", "email")
  disabled(type, email) {
    if (type === "link") {
    } else if (type === "email") {
      return !email;
    }
  },

  @discourseComputed("type", "inviteId")
  saveLabel(type, inviteId) {
    if (type === "link") {
      if (inviteId) {
        return "user.invited.invite.update_invite_link";
      } else {
        return "user.invited.invite.create_invite_link";
      }
    } else if (type === "email") {
      return "user.invited.invite.send_invite_email";
    }
  },

  @discourseComputed("type")
  isLink(type) {
    return type === "link";
  },

  @discourseComputed("type")
  isEmail(type) {
    return type === "email";
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
      : ajax("/invites", { type: "POST", data });

    promise.then((result) => this.setInvite(result.invite));
  },
});
