import Controller from "@ember/controller";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import discourseComputed from "discourse-common/utils/decorators";
import { flashAjaxError } from "discourse/lib/ajax-error";
import { emailValid } from "discourse/lib/utilities";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import I18n from "I18n";

export default Controller.extend(ModalFunctionality, {
  loading: false,

  usernamesAndEmails: null,
  setOwner: false,
  notifyUsers: false,

  onShow() {
    this.setProperties({
      loading: false,
      setOwner: false,
      notifyUsers: false,
      usernamesAndEmails: [],
    });
  },

  @discourseComputed("model.name", "model.full_name")
  rawTitle(name, fullName) {
    return I18n.t("groups.add_members.title", { group_name: fullName || name });
  },

  @discourseComputed("usernamesAndEmails.[]")
  usernames(usernamesAndEmails) {
    return usernamesAndEmails.reject(emailValid).join(",");
  },

  @discourseComputed("usernamesAndEmails.[]")
  emails(usernamesAndEmails) {
    return usernamesAndEmails.filter(emailValid).join(",");
  },

  @action
  setUsernamesAndEmails(usernamesAndEmails) {
    this.set("usernamesAndEmails", usernamesAndEmails);

    if (this.emails) {
      if (!this.usernames) {
        this.set("notifyUsers", false);
      }

      this.set("setOwner", false);
    }
  },

  @action
  addMembers() {
    if (isEmpty(this.usernamesAndEmails)) {
      return;
    }

    this.set("loading", true);

    const promise = this.setOwner
      ? this.model.addOwners(this.usernames, true, this.notifyUsers)
      : this.model.addMembers(
          this.usernames,
          true,
          this.notifyUsers,
          this.emails
        );

    promise
      .then(() => {
        this.transitionToRoute("group.members", this.get("model.name"), {
          queryParams: this.usernames ? { filter: this.usernames } : {},
        });

        this.send("closeModal");
      })
      .catch(flashAjaxError(this))
      .finally(() => this.set("loading", false));
  },
});
