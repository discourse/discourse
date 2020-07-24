import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import Controller from "@ember/controller";
import { extractError } from "discourse/lib/ajax-error";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
import { emailValid } from "discourse/lib/utilities";

export default Controller.extend(ModalFunctionality, {
  loading: false,
  setAsOwner: false,
  usernamesAndEmails: null,
  usernames: null,
  emails: null,

  onShow() {
    this.set("usernamesAndEmails", "");
    this.set("usernames", []);
    this.set("emails", []);
  },

  @discourseComputed("usernamesAndEmails", "loading")
  disableAddButton(usernamesAndEmails, loading) {
    return loading || !usernamesAndEmails || !(usernamesAndEmails.length > 0);
  },

  @discourseComputed("usernamesAndEmails")
  addingEmails(usernamesAndEmails) {
    let emails = [];
    let usernames = [];

    usernamesAndEmails.split(",").forEach(u => {
      emailValid(u) ? emails.push(u) : usernames.push(u);
    });

    this.set("emails", emails.join(","));
    this.set("usernames", usernames.join(","));
    return emails.length;
  },

  @action
  addMembers() {
    this.set("loading", true);

    if (this.addingEmails) {
      this.set("setAsOwner", false);
    }

    if (isEmpty(this.usernamesAndEmails)) {
      return;
    }

    const promise = this.setAsOwner
      ? this.model.addOwners(this.usernames, true)
      : this.model.addMembers(this.usernames, true, this.emails);

    promise
      .then(() => {
        let queryParams = {};

        if (this.usernames) {
          queryParams.filter = this.usernames;
        }

        this.transitionToRoute("group.members", this.get("model.name"), {
          queryParams
        });

        this.send("closeModal");
      })
      .catch(error => this.flash(extractError(error), "error"))
      .finally(() => this.set("loading", false));
  }
});
