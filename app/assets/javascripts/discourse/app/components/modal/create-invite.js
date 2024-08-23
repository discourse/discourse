import Component from "@ember/component";
import { action } from "@ember/object";
import { not, readOnly } from "@ember/object/computed";
import { extractError } from "discourse/lib/ajax-error";
import { getNativeContact } from "discourse/lib/pwa-utils";
import { sanitize } from "discourse/lib/text";
import { timeShortcuts } from "discourse/lib/time-shortcut";
import { emailValid, hostnameValid } from "discourse/lib/utilities";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import Group from "discourse/models/group";
import Invite from "discourse/models/invite";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";
import { FORMAT } from "select-kit/components/future-date-input-selector";

export default class CreateInvite extends Component.extend(
  bufferedProperty("invite")
) {
  allGroups = null;
  topics = null;
  flashText = null;
  flashClass = null;
  flashLink = false;
  inviteToTopic = false;
  limitToEmail = false;

  @readOnly("model.editing") editing;
  @not("isEmail") isLink;

  @discourseComputed("buffered.emailOrDomain")
  isEmail(emailOrDomain) {
    return emailValid(emailOrDomain?.trim());
  }

  @discourseComputed("buffered.emailOrDomain")
  isDomain(emailOrDomain) {
    return hostnameValid(emailOrDomain?.trim());
  }

  init() {
    super.init();

    Group.findAll().then((groups) => {
      this.set("allGroups", groups.filterBy("automatic", false));
    });

    this.set("invite", this.model.invite || Invite.create());
    this.set("topics", this.invite?.topics || this.model.topics || []);

    this.buffered.setProperties({
      max_redemptions_allowed: this.model.invite?.max_redemptions_allowed ?? 1,
      expires_at:
        this.model.invite?.expires_at ??
        moment()
          .add(this.siteSettings.invite_expiry_days, "days")
          .format(FORMAT),
      groupIds: this.model.groupIds ?? this.model.invite?.groupIds,
      topicId: this.model.invite?.topicId,
      topicTitle: this.model.invite?.topicTitle,
    });
  }

  save(opts) {
    const data = { ...this.buffered.buffer };

    if (data.emailOrDomain) {
      if (emailValid(data.emailOrDomain)) {
        data.email = data.emailOrDomain?.trim();
      } else if (hostnameValid(data.emailOrDomain)) {
        data.domain = data.emailOrDomain?.trim();
      }
      delete data.emailOrDomain;
    }

    if (data.groupIds !== undefined) {
      data.group_ids = data.groupIds.length > 0 ? data.groupIds : "";
      delete data.groupIds;
    }

    if (data.topicId !== undefined) {
      data.topic_id = data.topicId;
      delete data.topicId;
      delete data.topicTitle;
    }

    if (this.isLink) {
      if (this.invite.email) {
        data.email = data.custom_message = "";
      }
    } else if (this.isEmail) {
      if (this.invite.max_redemptions_allowed > 1) {
        data.max_redemptions_allowed = 1;
      }

      if (opts.sendEmail) {
        data.send_email = true;
        if (this.inviteToTopic) {
          data.invite_to_topic = true;
        }
      } else {
        data.skip_email = true;
      }
    }

    return this.invite
      .save(data)
      .then(() => {
        this.rollbackBuffer();

        const invites = this.model?.invites;
        if (invites && !invites.any((i) => i.id === this.invite.id)) {
          invites.unshiftObject(this.invite);
        }

        if (this.isEmail && opts.sendEmail) {
          this.closeModal();
        } else {
          this.setProperties({
            flashText: sanitize(I18n.t("user.invited.invite.invite_saved")),
            flashClass: "success",
            flashLink: !this.editing,
          });
        }
      })
      .catch((e) =>
        this.setProperties({
          flashText: sanitize(extractError(e)),
          flashClass: "error",
          flashLink: false,
        })
      );
  }

  @discourseComputed(
    "currentUser.staff",
    "siteSettings.invite_link_max_redemptions_limit",
    "siteSettings.invite_link_max_redemptions_limit_users"
  )
  maxRedemptionsAllowedLimit(staff, staffLimit, usersLimit) {
    return staff ? staffLimit : usersLimit;
  }

  @discourseComputed("buffered.expires_at")
  expiresAtLabel(expires_at) {
    const expiresAt = moment(expires_at);

    return expiresAt.isBefore()
      ? I18n.t("user.invited.invite.expired_at_time", {
          time: expiresAt.format("LLL"),
        })
      : I18n.t("user.invited.invite.expires_in_time", {
          time: moment.duration(expiresAt - moment()).humanize(),
        });
  }

  @discourseComputed("currentUser.staff", "currentUser.groups")
  canInviteToGroup(staff, groups) {
    return staff || groups.any((g) => g.owner);
  }

  @discourseComputed("currentUser.staff")
  canArriveAtTopic(staff) {
    if (staff && !this.siteSettings.must_approve_users) {
      return true;
    }
    return false;
  }

  @discourseComputed
  timeShortcuts() {
    const timezone = this.currentUser.user_option.timezone;
    const shortcuts = timeShortcuts(timezone);
    return [
      shortcuts.laterToday(),
      shortcuts.tomorrow(),
      shortcuts.laterThisWeek(),
      shortcuts.monday(),
      shortcuts.twoWeeks(),
      shortcuts.nextMonth(),
      shortcuts.twoMonths(),
      shortcuts.threeMonths(),
      shortcuts.fourMonths(),
      shortcuts.sixMonths(),
    ];
  }

  @action
  copied() {
    this.save({ sendEmail: false, copy: true });
  }

  @action
  saveInvite(sendEmail) {
    this.save({ sendEmail });
  }

  @action
  searchContact() {
    getNativeContact(this.capabilities, ["email"], false).then((result) => {
      this.set("buffered.email", result[0].email[0]);
    });
  }

  @action
  onChangeTopic(topicId, topic) {
    this.set("topics", [topic]);
    this.set("buffered.topicId", topicId);
  }
}
