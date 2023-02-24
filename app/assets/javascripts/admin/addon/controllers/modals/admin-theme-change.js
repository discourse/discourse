import Modal from "discourse/controllers/modal";
import { ajax } from "discourse/lib/ajax";

export default Modal.extend({
  loadDiff() {
    this.set("loading", true);
    ajax(
      "/admin/logs/staff_action_logs/" + this.get("model.id") + "/diff"
    ).then((diff) => {
      this.set("loading", false);
      this.set("diff", diff.side_by_side);
    });
  },
});
