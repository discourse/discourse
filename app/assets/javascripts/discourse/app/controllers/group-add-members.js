import Controller from "@ember/controller";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { emailValid } from "discourse/lib/utilities";
import { extractError } from "discourse/lib/ajax-error";
import { isEmpty } from "@ember/utils";
import { reads } from "@ember/object/computed";

export default Controller.extend(ModalFunctionality, {
  loading: false,
  setAsOwner: false,
  notifyUsers: false,
  usernamesAndEmails: null,
  emailsPresent: reads("emails.length"),

  onShow() {
    this.setProperties({
      usernamesAndEmails: [],
      setAsOwner: false,
      notifyUsers: false,
    });
  },

  @discourseComputed("usernamesAndEmails", "loading")
  disableAddButton(usernamesAndEmails, loading) {
    return loading || !usernamesAndEmails || !(usernamesAndEmails.length > 0);
  },

  @discourseComputed("usernamesAndEmails")
  notifyUsersDisabled() {
    return this.usernames.length === 0 && this.emails.length > 0;
  },

  @discourseComputed("model.name", "model.full_name")
  title(name, fullName) {
    return I18n.t("groups.add_members.title", { group_name: fullName || name });
  },

  @discourseComputed("usernamesAndEmails.[]")
  emails(usernamesAndEmails) {
    return usernamesAndEmails.filter(emailValid).join(",");
  },

  @discourseComputed("usernamesAndEmails.[]")
  usernames(usernamesAndEmails) {
    return usernamesAndEmails.reject(emailValid).join(",");
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
});
