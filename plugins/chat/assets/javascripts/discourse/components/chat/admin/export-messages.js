import Component from "@glimmer/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "I18n";

export default class ChatAdminExportMessages extends Component {
  @service chatAdminApi;
  @service dialog;

  @action
  async exportMessages() {
    try {
      await this.chatAdminApi.exportMessages();
      this.dialog.alert(
        I18n.t("chat.admin.export_messages.export_has_started")
      );
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
