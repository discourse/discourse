import { action } from "@ember/object";
import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { downloadGoogle, downloadIcs } from "discourse/lib/download-calendar";

export default Controller.extend(ModalFunctionality, {
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
