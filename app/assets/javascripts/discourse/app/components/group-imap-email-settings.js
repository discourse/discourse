import Component from "@ember/component";
import { later } from "@ember/runloop";
import I18n from "I18n";
import bootbox from "bootbox";
import { isEmpty } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed, { on } from "discourse-common/utils/decorators";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default Component.extend({
  tagName: "",
  group: null,
  form: null,

  @discourseComputed("group.imap_mailboxes")
  mailboxes(imapMailboxes) {
    return imapMailboxes.map((mailbox) => ({ name: mailbox, value: mailbox }));
  },

  @discourseComputed("group.imap_mailbox_name", "mailboxes.length")
  mailboxSelected(mailboxName, mailboxesSize) {
    if (mailboxesSize === 0) {
      return true;
    }

    return !isEmpty(mailboxName);
  },

  @action
  resetSettingsValid() {
    if (this.initializing) {
      return;
    }
    this.set("group.imapSettingsValid", false);
  },

  @on("init")
  _fillForm() {
    this.initializing = true;
    this.set("form", {
      imap_server: this.group.imap_server,
      imap_port: this.group.imap_port,
      imap_ssl: this.group.imap_ssl,
    });

    later(() => {
      this.set(
        "group.imapSettingsValid",
        this.group.imap_enabled && this.form.imap_server
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
          server: "imap.gmail.com",
          port: "993",
          ssl: true,
        };
    }

    if (providerDetails) {
      this.set("form.imap_server", providerDetails.server);
      this.set("form.imap_port", providerDetails.port);
      this.set("form.imap_ssl", providerDetails.ssl);
    }
  },

  @action
  testImapSettings() {
    let settings = {
      host: this.form.imap_server,
      port: this.form.imap_port,
      ssl: this.form.imap_ssl,
      username: this.group.email_username,
      password: this.group.email_password,
    };

    for (const setting in settings) {
      if (isEmpty(settings[setting])) {
        return bootbox.alert(I18n.t("groups.manage.email.settings_required"));
      }
    }

    this.set("testingSettings", true);
    this.set("group.imapSettingsValid", false);

    return ajax(`/groups/${this.group.id}/test_email_settings`, {
      type: "POST",
      data: Object.assign(settings, { protocol: "imap" }),
    })
      .then(() => {
        this.set("group.imapSettingsValid", true);
        this.setProperties({
          "group.imap_server": this.form.imap_server,
          "group.imap_port": this.form.imap_port,
          "group.imap_ssl": this.form.imap_ssl,
        });
      })
      .catch(popupAjaxError)
      .finally(() => this.set("testingSettings", false));
  },
});
