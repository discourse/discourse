import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  actions: {
    finishConnect() {
      ajax({
        url: `/associate/${encodeURIComponent(this.model.token)}`,
        type: "POST"
      })
        .then(result => {
          if (result.success) {
            this.transitionToRoute(
              "preferences.account",
              this.currentUser.findDetails()
            );
            this.send("closeModal");
          } else {
            this.set("model.error", result.error);
          }
        })
        .catch(popupAjaxError);
    }
  }
});
