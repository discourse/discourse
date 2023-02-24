import { action } from "@ember/object";
import Modal from "discourse/controllers/modal";
import { downloadGoogle, downloadIcs } from "discourse/lib/download-calendar";

export default Modal.extend({
  selectedCalendar: "ics",
  remember: false,

  @action
  downloadCalendar() {
    if (this.remember) {
      this.currentUser.user_option.set(
        "default_calendar",
        this.selectedCalendar
      );
      this.currentUser.save(["default_calendar"]);
    }
    if (this.selectedCalendar === "ics") {
      downloadIcs(this.model.title, this.model.dates);
    } else {
      downloadGoogle(this.model.title, this.model.dates);
    }
    this.send("closeModal");
  },
});
