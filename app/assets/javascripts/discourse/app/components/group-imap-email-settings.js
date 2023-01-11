import Component from "@ember/component";
import emailProviderDefaultSettings from "discourse/lib/email-provider-default-settings";
import { isEmpty } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed, { on } from "discourse-common/utils/decorators";
import EmberObject, { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

export default Component.extend({
  tagName: "",
  form: null,

  @discourseComputed(
    "group.email_username",
    "group.email_password",
    "form.imap_server",
    "form.imap_port"
  )
  missingSettings(email_username, email_password, imap_server, imap_port) {
    return [email_username, email_password, imap_server, imap_port].some(
      (value) => isEmpty(value)
    );
  },

  @discourseComputed("group.imap_mailboxes")
  mailboxes(imapMailboxes) {
    if (!imapMailboxes) {
      return [];
    }
    return imapMailboxes.map((mailbox) => ({ name: mailbox, value: mailbox }));
  },

  @discourseComputed("group.imap_mailbox_name", "mailboxes.length")
  mailboxSelected(mailboxName, mailboxesSize) {
    return mailboxesSize === 0 || !isEmpty(mailboxName);
  },

  @action
  resetSettingsValid() {
    this.set("imapSettingsValid", false);
  },

  @on("init")
  _fillForm() {
    this.set(
      "form",
      EmberObject.create({
        imap_server: this.group.imap_server,
        imap_port: (this.group.imap_port || "").toString(),
        imap_ssl: this.group.imap_ssl,
      })
    );
  },

  @action
  prefillSettings(provider, event) {
    event?.preventDefault();
    this.form.setProperties(emailProviderDefaultSettings(provider, "imap"));
  },

  @action
  testImapSettings() {
    const settings = {
      host: this.form.imap_server,
      port: this.form.imap_port,
      ssl: this.form.imap_ssl,
      username: this.group.email_username,
      password: this.group.email_password,
    };

    this.set("testingSettings", true);
    this.set("imapSettingsValid", false);

    return ajax(`/groups/${this.group.id}/test_email_settings`, {
      type: "POST",
      data: Object.assign(settings, { protocol: "imap" }),
    })
      .then(() => {
        this.set("imapSettingsValid", true);
        this.group.setProperties({
          imap_server: this.form.imap_server,
          imap_port: this.form.imap_port,
          imap_ssl: this.form.imap_ssl,
        });
      })
      .catch(popupAjaxError)
      .finally(() => this.set("testingSettings", false));
  },
});
