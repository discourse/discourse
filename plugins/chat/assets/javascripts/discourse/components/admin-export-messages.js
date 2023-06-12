import Component from "@ember/component";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AdminExportMessages extends Component {
  @service chatAdminApi;

  @action
  async exportMessages() {
    try {
      await this.chatAdminApi.exportMessages();
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
