import Component from "@ember/component";
import { later } from "@ember/runloop";
import I18n from "I18n";
import bootbox from "bootbox";
import { isEmpty } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { on } from "discourse-common/utils/decorators";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default Component.extend({
  tagName: "",
  group: null,
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
    this.set("form", {
      email_username: this.group.email_username,
      email_password: this.group.email_password,
      smtp_server: this.group.smtp_server,
      smtp_port: this.group.smtp_port,
      smtp_ssl: this.group.smtp_ssl,
    });

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
    let providerDetails = null;
    switch (provider) {
      case "gmail":
        providerDetails = {
          server: "smtp.gmail.com",
          port: "587",
          ssl: true,
        };
    }

    if (providerDetails) {
      this.set("form.smtp_server", providerDetails.server);
      this.set("form.smtp_port", providerDetails.port);
      this.set("form.smtp_ssl", providerDetails.ssl);
    }
  },

  @action
  testSmtpSettings() {
    let settings = {
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
        this.set("group.smtpSettingsValid", true);
        this.setProperties({
          "group.smtp_server": this.form.smtp_server,
          "group.smtp_port": this.form.smtp_port,
          "group.smtp_ssl": this.form.smtp_ssl,
          "group.email_username": this.form.email_username,
          "group.email_password": this.form.email_password,
        });
      })
      .catch(popupAjaxError)
      .finally(() => this.set("testingSettings", false));
  },
});
