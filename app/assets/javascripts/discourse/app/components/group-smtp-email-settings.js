import Component from "@ember/component";
import { on } from "discourse-common/utils/decorators";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",
  group: null,

  form: null,
  smtpSettingsNotOk: true,

  @on("init")
  _fillForm() {
    this.set("form", {
      username: this.group.email_username,
      password: this.group.email_password,
      smtp_server: this.group.smtp_server,
      smtp_port: this.group.smtp_port,
      smtp_ssl: this.group.smtp_ssl,
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
  testSmtpSettings() {},
});
