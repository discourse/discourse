import discourseComputed from "discourse-common/utils/decorators";
import { isEmpty } from "@ember/utils";
import Controller from "@ember/controller";
import { extractError } from "discourse/lib/ajax-error";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  loading: false,
  setAsOwner: false,

  @discourseComputed("model.usernames", "loading")
  disableAddButton(usernames, loading) {
    return loading || !usernames || !(usernames.length > 0);
  },

  actions: {
    addMembers() {
      this.set("loading", true);

      const model = this.model;
      const usernames = model.get("usernames");
      if (isEmpty(usernames)) {
        return;
      }
      let promise;

      if (this.setAsOwner) {
        promise = model.addOwners(usernames, true);
      } else {
        promise = model.addMembers(usernames, true);
      }

      promise
        .then(() => {
          this.transitionToRoute("group.members", this.get("model.name"), {
            queryParams: { filter: usernames }
          });

          model.set("usernames", null);
          this.send("closeModal");
        })
        .catch(error => {
          this.flash(extractError(error), "error");
        })
        .finally(() => this.set("loading", false));
    }
  }
});
