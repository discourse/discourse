import discourseComputed from "discourse-common/utils/decorators";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import IncomingEmail from "admin/models/incoming-email";
import { longDate } from "discourse/lib/formatter";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Controller.extend(ModalFunctionality, {
  @discourseComputed("model.date")
  date(d) {
    return longDate(d);
  },

  load(id) {
    return IncomingEmail.find(id).then(result => this.set("model", result));
  },

  loadFromBounced(id) {
    return IncomingEmail.findByBounced(id)
      .then(result => this.set("model", result))
      .catch(error => {
        this.send("closeModal");
        popupAjaxError(error);
      });
  }
});
