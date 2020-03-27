import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  @discourseComputed("model.imap_mailboxes.mailboxes")
  mailboxes(imapMailboxes) {
    return imapMailboxes.map(mailbox => ({ name: mailbox, value: mailbox }));
  }
});
