import Controller from "@ember/controller";
import IncomingEmail from "admin/models/incoming-email";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import discourseComputed from "discourse-common/utils/decorators";
import { longDate } from "discourse/lib/formatter";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminIncomingEmailController extends Controller.extend(
  ModalFunctionality
) {
  @discourseComputed("model.date")
  date(d) {
    return longDate(d);
  }

  load(id) {
    return IncomingEmail.find(id).then((result) => this.set("model", result));
  }

  loadFromBounced(id) {
    return IncomingEmail.findByBounced(id)
      .then((result) => this.set("model", result))
      .catch((error) => {
        this.send("closeModal");
        popupAjaxError(error);
      });
  }
}
