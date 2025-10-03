import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import IncomingEmailModal from "admin/components/modal/incoming-email";
import IncomingEmail from "admin/models/incoming-email";

export default class AdminEmailLogsRoute extends DiscourseRoute {
  @service modal;

  setupController(controller) {
    super.setupController(...arguments);
    controller.set("status", this.status);
  }

  @action
  async showIncomingEmail(id) {
    const model = await IncomingEmail.find(id);
    this.modal.show(IncomingEmailModal, { model });
  }
}
