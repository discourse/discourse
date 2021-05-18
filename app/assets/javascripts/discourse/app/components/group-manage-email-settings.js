import Component from "@ember/component";
import I18n from "I18n";
import bootbox from "bootbox";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",

  group: null,

  @action
  smtpEnabledChange(event) {
    if (!event.target.checked && this.group.smtp_enabled) {
      bootbox.confirm(
        I18n.t("groups.manage.email.smtp_disable_confirm"),
        (result) => {
          this.clearAllEmailSettingsOnSave = result;

          if (!result) {
            this.group.set("smtp_enabled", true);
          }
        }
      );
    }

    if (event.target.checked) {
      this.clearAllEmailSettingsOnSave = false;
    }

    this.group.set("smtp_enabled", event.target.checked);
  },

  @action
  imapEnabledChange(event) {
    if (!event.target.checked && this.group.imap_enabled) {
      bootbox.confirm(
        I18n.t("groups.manage.email.imap_disable_confirm"),
        (result) => {
          this.clearImapEmailSettingsOnSave = result;

          if (!result) {
            this.group.set("imap_enabled", true);
          }
        }
      );
    }

    if (event.target.checked) {
      this.clearImapEmailSettingsOnSave = false;
    }

    this.group.set("imap_enabled", event.target.checked);
  },

  @action
  beforeSave() {
    if (this.clearAllEmailSettingsOnSave) {
      this.group.setProperties({
        smtp_port: null,
        smtp_server: null,
        email_username: null,
        email_password: null,
        imap_server: null,
        imap_port: null,
      });
    }

    if (this.clearImapEmailSettingsOnSave) {
      this.group.setProperties({
        imap_server: null,
        imap_port: null,
      });
    }
  },
});
