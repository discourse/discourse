import Controller from "@ember/controller";
import DiscourseURL from "discourse/lib/url";
import I18n from "I18n";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import { bind } from "discourse-common/utils/decorators";

export default class AdminMergeUsersProgressController extends Controller.extend(
  ModalFunctionality
) {
  message = I18n.t("admin.user.merging_user");

  onShow() {
    this.messageBus.subscribe("/merge_user", this.onMessage);
  }

  onClose() {
    this.messageBus.unsubscribe("/merge_user", this.onMessage);
  }

  @bind
  onMessage(data) {
    if (data.merged) {
      if (/^\/admin\/users\/list\//.test(location)) {
        DiscourseURL.redirectTo(location);
      } else {
        DiscourseURL.redirectTo(
          `/admin/users/${data.user.id}/${data.user.username}`
        );
      }
    } else if (data.message) {
      this.set("message", data.message);
    } else if (data.failed) {
      this.set("message", I18n.t("admin.user.merge_failed"));
    }
  }
}
