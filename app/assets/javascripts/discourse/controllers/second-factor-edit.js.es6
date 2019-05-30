import { default as computed } from "ember-addons/ember-computed-decorators";
import { default as DiscourseURL, userPath } from "discourse/lib/url";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { SECOND_FACTOR_METHODS } from "discourse/models/user";

export default Ember.Controller.extend(ModalFunctionality, {
  actions: {
    disableSecondFactor() {
      this.user
        .updateSecondFactor(
          this.model.id,
          this.model.name,
          true,
          this.model.method
        )
        .then(response => {
          if (response.error) {
            return;
          }
          this.markDirty();
        })
        .catch(error => {
          this.send("closeModal");
          this.onError(error);
        })
        .finally(() => {
          this.set("loading", false);
          this.send("closeModal");
        });
    },

    editSecondFactor() {
      this.user
        .updateSecondFactor(
          this.model.id,
          this.model.name,
          false,
          this.model.method
        )
        .then(response => {
          if (response.error) {
            return;
          }
          this.markDirty();
        })
        .catch(error => {
          this.send("closeModal");
          this.onError(error);
        })
        .finally(() => {
          this.set("loading", false);
          this.send("closeModal");
        });
    }
  }
});
