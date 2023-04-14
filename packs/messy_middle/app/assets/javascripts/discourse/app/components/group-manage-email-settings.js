import Component from "@ember/component";
import { isEmpty } from "@ember/utils";
import discourseComputed, { on } from "discourse-common/utils/decorators";
import I18n from "I18n";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",
  dialog: service(),

  imapSettingsValid: false,
  smtpSettingsValid: false,

  @on("init")
  _determineSettingsValid() {
    this.set(
      "imapSettingsValid",
      this.group.imap_enabled && this.group.imap_server
    );
    this.set(
      "smtpSettingsValid",
      this.group.smtp_enabled && this.group.smtp_server
    );
  },

  @discourseComputed(
    "emailSettingsValid",
    "group.smtp_enabled",
    "group.imap_enabled"
  )
  enableImapSettings(emailSettingsValid, smtpEnabled, imapEnabled) {
    return smtpEnabled && (emailSettingsValid || imapEnabled);
  },

  @discourseComputed(
    "smtpSettingsValid",
    "imapSettingsValid",
    "group.smtp_enabled",
    "group.imap_enabled"
  )
  emailSettingsValid(
    smtpSettingsValid,
    imapSettingsValid,
    smtpEnabled,
    imapEnabled
  ) {
    return (
      (!smtpEnabled || smtpSettingsValid) && (!imapEnabled || imapSettingsValid)
    );
  },

  _anySmtpFieldsFilled() {
    return [
      this.group.smtp_server,
      this.group.smtp_port,
      this.group.email_username,
      this.group.email_password,
    ].some((value) => !isEmpty(value));
  },

  _anyImapFieldsFilled() {
    return [this.group.imap_server, this.group.imap_port].some(
      (value) => !isEmpty(value)
    );
  },

  @action
  smtpEnabledChange(event) {
    if (
      !event.target.checked &&
      this.group.smtp_enabled &&
      this._anySmtpFieldsFilled()
    ) {
      this.dialog.confirm({
        message: I18n.t("groups.manage.email.smtp_disable_confirm"),
        didConfirm: () => this.group.set("smtp_enabled", true),
        didCancel: () => this.group.set("imap_enabled", false),
      });
    }

    this.group.set("smtp_enabled", event.target.checked);
  },

  @action
  imapEnabledChange(event) {
    if (
      !event.target.checked &&
      this.group.imap_enabled &&
      this._anyImapFieldsFilled()
    ) {
      this.dialog.confirm({
        message: I18n.t("groups.manage.email.imap_disable_confirm"),
        didConfirm: () => this.group.set("imap_enabled", true),
      });
    }

    this.group.set("imap_enabled", event.target.checked);
  },

  @action
  afterSave() {
    // reload the group to get the updated imap_mailboxes
    this.store.find("group", this.group.name).then(() => {
      this._determineSettingsValid();
    });
  },
});
