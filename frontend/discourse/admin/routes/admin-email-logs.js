import { action } from "@ember/object";
import { service } from "discourse/lib/service";
import IncomingEmail from "discourse/admin/models/incoming-email";
import DiscourseRoute from "discourse/routes/discourse";
import ModalService from "discourse/services/modal";

export default class AdminEmailLogsRoute extends DiscourseRoute {
  @service(() => ModalService) modal;

  @action
  async showIncomingEmail(id) {
    const model = await IncomingEmail.find(id);
    this.modal.show(
      () => import("discourse/admin/components/modal/incoming-email"),
      { model }
    );
  }
}
