import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { extractError } from "discourse/lib/ajax-error";
import { emailValid } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class GroupAddMembers extends Component {
  @service currentUser;
  @service router;

  @tracked loading = false;
  @tracked setOwner = false;
  @tracked notifyUsers = false;
  @tracked usernamesAndEmails = [];
  @tracked flash;

  get title() {
    return i18n("groups.add_members.title", {
      group_name: this.args.model.fullName || this.args.model.name,
    });
  }

  get usernames() {
    return this.usernamesAndEmails.reject(emailValid).join(",");
  }

  get emails() {
    return this.usernamesAndEmails.filter(emailValid).join(",");
  }

  @action
  setUsernamesAndEmails(usernamesAndEmails) {
    this.usernamesAndEmails = usernamesAndEmails;
    if (this.emails) {
      if (!this.usernames) {
        this.notifyUsers = false;
      }
      this.setOwner = false;
    }
  }

  @action
  async addMembers() {
    if (isEmpty(this.usernamesAndEmails)) {
      return;
    }

    this.loading = true;

    try {
      if (this.setOwner) {
        await this.args.model.addOwners(this.usernames, true, this.notifyUsers);
      } else {
        await this.args.model.addMembers(
          this.usernames,
          true,
          this.notifyUsers,
          this.emails
        );
      }

      this.router.transitionTo("group.members", this.args.model.name, {
        queryParams: { ...(this.usernames && { filter: this.usernames }) },
      });
      this.args.closeModal();
    } catch (e) {
      this.flash = extractError(e);
    } finally {
      this.loading = false;
    }
  }
}
