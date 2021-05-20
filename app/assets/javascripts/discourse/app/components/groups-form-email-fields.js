import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  @discourseComputed("model.imap_mailboxes")
  mailboxes(imapMailboxes) {
    return imapMailboxes.map((mailbox) => ({ name: mailbox, value: mailbox }));
  },

  @discourseComputed("model.imap_old_emails")
  oldEmails(oldEmails) {
    return oldEmails || 0;
  },

  @discourseComputed("model.imap_old_emails", "model.imap_new_emails")
  totalEmails(oldEmails, newEmails) {
    return (oldEmails || 0) + (newEmails || 0);
  },
});
