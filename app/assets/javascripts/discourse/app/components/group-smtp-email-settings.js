import Component from "@ember/component";
import { later } from "@ember/runloop";
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
    if (this.initializing) {
      return;
    }
    this.set("group.smtpSettingsValid", false);
  },

  @on("init")
  _fillForm() {
    this.initializing = true;
    this.set(
      "form",
      EmberObject.create({
        email_username: this.group.email_username,
        email_password: this.group.email_password,
        smtp_server: this.group.smtp_server,
        smtp_port: this.group.smtp_port,
        smtp_ssl: this.group.smtp_ssl,
      })
    );

    later(() => {
      this.set(
        "group.smtpSettingsValid",
        this.group.smtp_enabled && this.form.smtp_server
      );
      this.initializing = false;
    });
  },

  @action
  prefillSettings(provider) {
    switch (provider) {
      case "gmail":
        this.form.setProperties({
          smtp_server: "smtp.gmail.com",
          smtp_port: "587",
          smtp_ssl: true,
        });
    }
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
    this.set("group.smtpSettingsValid", false);

    return ajax(`/groups/${this.group.id}/test_email_settings`, {
      type: "POST",
      data: Object.assign(settings, { protocol: "smtp" }),
    })
      .then(() => {
        this.group.setProperties({
          smtpSettingsValid: true,
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
