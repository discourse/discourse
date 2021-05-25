import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "I18n";
import bootbox from "bootbox";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",

  clearImapEmailSettingsOnSave: false,
  clearAllEmailSettingsOnSave: false,

  @discourseComputed(
    "group.emailSettingsValid",
    "group.smtp_enabled",
    "group.imap_enabled"
  )
  enableImapSettings(emailSettingsValid, smtpEnabled, imapEnabled) {
    return smtpEnabled && (emailSettingsValid || imapEnabled);
  },

  @discourseComputed(
    "group.emailSettingsValid",
    "clearImapEmailSettingsOnSave",
    "clearAllEmailSettingsOnSave"
  )
  disableSaveButton(
    emailSettingsValid,
    clearImapEmailSettingsOnSave,
    clearAllEmailSettingsOnSave
  ) {
    return (
      !emailSettingsValid &&
      !clearImapEmailSettingsOnSave &&
      !clearAllEmailSettingsOnSave
    );
  },

  @action
  smtpEnabledChange(event) {
    if (!event.target.checked && this.group.smtp_enabled) {
      bootbox.confirm(
        I18n.t("groups.manage.email.smtp_disable_confirm"),
        (result) => {
          this.set("clearAllEmailSettingsOnSave", result);

          if (!result) {
            this.group.set("smtp_enabled", true);
          } else {
            this.group.set("imap_enabled", false);
          }
        }
      );
    }

    if (event.target.checked) {
      this.set("clearAllEmailSettingsOnSave", false);
    }

    this.group.set("smtp_enabled", event.target.checked);
  },

  @action
  imapEnabledChange(event) {
    if (!event.target.checked && this.group.imap_enabled) {
      bootbox.confirm(
        I18n.t("groups.manage.email.imap_disable_confirm"),
        (result) => {
          this.set("clearImapEmailSettingsOnSave", result);

          if (!result) {
            this.group.set("imap_enabled", true);
          }
        }
      );
    }

    if (event.target.checked) {
      this.set("clearImapEmailSettingsOnSave", false);
    }

    this.group.set("imap_enabled", event.target.checked);
  },

  @action
  afterSave() {
    // reload the group to get the updated imap_mailboxes
    this.store.find("group", this.group.name);
  },

  @action
  beforeSave() {
    if (this.clearAllEmailSettingsOnSave) {
      this.group.setProperties({
        smtp_port: null,
        smtp_ssl: false,
        smtp_server: null,
        email_username: null,
        email_password: null,
        imap_server: null,
        imap_port: null,
        imap_ssl: false,
        imap_mailbox_name: null,
      });
    }

    if (this.clearImapEmailSettingsOnSave) {
      this.group.setProperties({
        imap_server: null,
        imap_port: null,
        imap_ssl: false,
        imap_mailbox_name: null,
      });
    }
  },
});
