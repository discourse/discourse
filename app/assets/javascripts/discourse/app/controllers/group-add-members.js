import Controller from "@ember/controller";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { emailValid } from "discourse/lib/utilities";
import { extractError } from "discourse/lib/ajax-error";
import { isEmpty } from "@ember/utils";

export default Controller.extend(ModalFunctionality, {
  loading: false,
  setAsOwner: false,
  notifyUsers: false,
  usernamesAndEmails: null,
  usernames: null,
  emails: null,

  onShow() {
    this.setProperties({
      usernamesAndEmails: "",
      usernames: [],
      emails: [],
      setAsOwner: false,
      notifyUsers: false,
    });
  },

  @discourseComputed("usernamesAndEmails", "loading")
  disableAddButton(usernamesAndEmails, loading) {
    return loading || !usernamesAndEmails || !(usernamesAndEmails.length > 0);
  },

  @discourseComputed("usernamesAndEmails")
  emailsPresent() {
    this._splitEmailsAndUsernames();
    return this.emails.length;
  },

  @discourseComputed("usernamesAndEmails")
  notifyUsersDisabled() {
    this._splitEmailsAndUsernames();
    return this.usernames.length === 0 && this.emails.length > 0;
  },

  @discourseComputed("model.name", "model.full_name")
  title(name, fullName) {
    return I18n.t("groups.add_members.title", { group_name: fullName || name });
  },

  @action
  addMembers() {
    this.set("loading", true);

    if (this.emailsPresent) {
      this.set("setAsOwner", false);
    }

    if (this.notifyUsersDisabled) {
      this.set("notifyUsers", false);
    }

    if (isEmpty(this.usernamesAndEmails)) {
      return;
    }

    const promise = this.setAsOwner
      ? this.model.addOwners(this.usernames, true, this.notifyUsers)
      : this.model.addMembers(
          this.usernames,
          true,
          this.notifyUsers,
          this.emails
        );

    promise
      .then(() => {
        let queryParams = {};

        if (this.usernames) {
          queryParams.filter = this.usernames;
        }

        this.transitionToRoute("group.members", this.get("model.name"), {
          queryParams,
        });

        this.send("closeModal");
      })
      .catch((error) => this.flash(extractError(error), "error"))
      .finally(() => this.set("loading", false));
  },

  _splitEmailsAndUsernames() {
    let emails = [];
    let usernames = [];

    this.usernamesAndEmails.split(",").forEach((u) => {
      emailValid(u) ? emails.push(u) : usernames.push(u);
    });

    this.set("emails", emails.join(","));
    this.set("usernames", usernames.join(","));
  },
});
