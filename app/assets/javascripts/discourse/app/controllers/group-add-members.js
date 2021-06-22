import Controller from "@ember/controller";
import { action } from "@ember/object";
import { isEmpty } from "@ember/utils";
import discourseComputed from "discourse-common/utils/decorators";
import { extractError } from "discourse/lib/ajax-error";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import I18n from "I18n";

export default Controller.extend(ModalFunctionality, {
  loading: false,

  usernames: null,
  setOwner: false,
  notifyUsers: false,

  onShow() {
    this.setProperties({
      loading: false,
      setOwner: false,
      notifyUsers: false,
      usernames: [],
    });
  },

  @discourseComputed("model.name", "model.full_name")
  rawTitle(name, fullName) {
    return I18n.t("groups.add_members.title", { group_name: fullName || name });
  },

  @action
  addMembers() {
    if (isEmpty(this.usernames)) {
      return;
    }

    this.set("loading", true);

    const usernames = this.usernames.join(",");
    const promise = this.setOwner
      ? this.model.addOwners(usernames, true, this.notifyUsers)
      : this.model.addMembers(usernames, true, this.notifyUsers);

    promise
      .then(() => {
        this.transitionToRoute("group.members", this.get("model.name"), {
          queryParams: usernames ? { filter: usernames } : {},
        });

        this.send("closeModal");
      })
      .catch((error) => this.flash(extractError(error), "error"))
      .finally(() => this.set("loading", false));
  },
});
