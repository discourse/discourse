import { action } from "@ember/object";
import { service } from "@ember/service";
import IncomingEmail from "discourse/admin/models/incoming-email";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminEmailLogsRoute extends DiscourseRoute {
  @service modal;

  @action
  async showIncomingEmail(id) {
    const model = await IncomingEmail.find(id);
    this.modal.show(
      () => import("discourse/admin/components/modal/incoming-email"),
      { model }
    );
  }
}
