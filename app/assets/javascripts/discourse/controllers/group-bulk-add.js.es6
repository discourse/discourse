import Controller from "@ember/controller";
import computed from "ember-addons/ember-computed-decorators";
import { extractError } from "discourse/lib/ajax-error";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { ajax } from "discourse/lib/ajax";

export default Controller.extend(ModalFunctionality, {
  loading: false,

  @computed("input", "loading", "result")
  disableAddButton(input, loading, result) {
    return loading || Ember.isEmpty(input) || input.length <= 0 || result;
  },

  actions: {
    cancel() {
      this.set("result", null);
    },

    add() {
      this.setProperties({
        loading: true,
        result: null
      });

      const users = this.input
        .split("\n")
        .uniq()
        .reject(x => x.length === 0);

      ajax("/admin/groups/bulk", {
        data: { users, group_id: this.get("model.id") },
        method: "PUT"
      })
        .then(result => {
          this.set("result", result);

          if (result.users_not_added) {
            this.set("result.invalidUsers", result.users_not_added.join(", "));
          }
        })
        .catch(error => {
          this.flash(extractError(error), "error");
        })
        .finally(() => {
          this.set("loading", false);
        });
    }
  }
});
