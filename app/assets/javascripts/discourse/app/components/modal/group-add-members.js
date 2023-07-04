import Component from "@glimmer/component";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { tracked } from "@glimmer/tracking";
import { emailValid } from "discourse/lib/utilities";
import I18n from "I18n";
import { inject as service } from "@ember/service";

export default class GroupAddMembers extends Component {
  @service currentUser;
  @service router;

  @tracked loading = false;
  @tracked setOwner = false;
  @tracked notifyUsers = false;
  @tracked usernamesAndEmails = [];
  @tracked flash;

  get title() {
    return I18n.t("groups.add_members.title", {
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
  addMembers() {
    if (isEmpty(this.usernamesAndEmails)) {
      return;
    }
    this.loading = true;
    const promise = this.setOwner
      ? this.args.model.addOwners(this.usernames, true, this.notifyUsers)
      : this.args.model.addMembers(
          this.usernames,
          true,
          this.notifyUsers,
          this.emails
        );

    promise
      .then(() => {
        this.router.transitionTo("group.members", this.args.model.name, {
          queryParams: { ...(this.usernames && { filter: this.usernames }) },
        });
        this.args.closeModal();
      })
      .catch((e) => (this.flash = e))
      .finally(() => (this.loading = false));
  }
}
