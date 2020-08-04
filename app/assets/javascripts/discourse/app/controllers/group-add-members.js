import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import Controller from "@ember/controller";
import { extractError } from "discourse/lib/ajax-error";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { action } from "@ember/object";

export default Controller.extend(ModalFunctionality, {
  loading: false,
  setAsOwner: false,

  @discourseComputed("model.usernames", "loading")
  disableAddButton(usernames, loading) {
    return loading || !usernames || !(usernames.length > 0);
  },

  @action
  addMembers() {
    this.set("loading", true);

    const usernames = this.model.usernames;
    if (isEmpty(usernames)) {
      return;
    }
    let promise;

    if (this.setAsOwner) {
      promise = this.model.addOwners(usernames, true);
    } else {
      promise = this.model.addMembers(usernames, true);
    }

    promise
      .then(() => {
        this.transitionToRoute("group.members", this.get("model.name"), {
          queryParams: { filter: usernames }
        });

        this.model.set("usernames", null);
        this.send("closeModal");
      })
      .catch(error => this.flash(extractError(error), "error"))
      .finally(() => this.set("loading", false));
  }
});
