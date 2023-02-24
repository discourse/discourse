import IncomingEmail from "admin/models/incoming-email";
import Modal from "discourse/controllers/modal";
import discourseComputed from "discourse-common/utils/decorators";
import { longDate } from "discourse/lib/formatter";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default Modal.extend({
  @discourseComputed("model.date")
  date(d) {
    return longDate(d);
  },

  load(id) {
    return IncomingEmail.find(id).then((result) => this.set("model", result));
  },

  loadFromBounced(id) {
    return IncomingEmail.findByBounced(id)
      .then((result) => this.set("model", result))
      .catch((error) => {
        this.send("closeModal");
        popupAjaxError(error);
      });
  },
});
