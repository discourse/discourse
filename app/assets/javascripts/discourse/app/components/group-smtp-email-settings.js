import Component from "@ember/component";
import emailProviderDefaultSettings from "discourse/lib/email-provider-default-settings";
import I18n from "I18n";
import bootbox from "bootbox";
import { isEmpty } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { on } from "discourse-common/utils/decorators";
import EmberObject, { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default Component.extend({
  tagName: "",
  form: null,

  @action
  resetSettingsValid() {
    this.set("smtpSettingsValid", false);
  },

  @on("init")
  _fillForm() {
    this.set(
      "form",
      EmberObject.create({
        email_username: this.group.email_username,
        email_password: this.group.email_password,
        smtp_server: this.group.smtp_server,
        smtp_port: (this.group.smtp_port || "").toString(),
        smtp_ssl: this.group.smtp_ssl,
      })
    );
  },

  @action
  prefillSettings(provider) {
    this.form.setProperties(emailProviderDefaultSettings(provider, "smtp"));
  },

  @action
  testSmtpSettings() {
    const settings = {
      host: this.form.smtp_server,
      port: this.form.smtp_port,
      ssl: this.form.smtp_ssl,
      username: this.form.email_username,
      password: this.form.email_password,
    };

    for (const setting in settings) {
      if (isEmpty(settings[setting])) {
        return bootbox.alert(I18n.t("groups.manage.email.settings_required"));
      }
    }

    this.set("testingSettings", true);
    this.set("smtpSettingsValid", false);

    return ajax(`/groups/${this.group.id}/test_email_settings`, {
      type: "POST",
      data: Object.assign(settings, { protocol: "smtp" }),
    })
      .then(() => {
        this.set("smtpSettingsValid", true);
        this.group.setProperties({
          smtp_server: this.form.smtp_server,
          smtp_port: this.form.smtp_port,
          smtp_ssl: this.form.smtp_ssl,
          email_username: this.form.email_username,
          email_password: this.form.email_password,
        });
      })
      .catch(popupAjaxError)
      .finally(() => this.set("testingSettings", false));
  },
});
