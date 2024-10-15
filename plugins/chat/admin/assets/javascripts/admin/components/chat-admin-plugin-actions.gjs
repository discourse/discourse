import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import I18n from "discourse-i18n";

export default class ChatAdminPluginActions extends Component {
  @service dialog;
  @service chatAdminApi;

  @action
  confirmExportMessages() {
    return this.dialog.confirm({
      message: I18n.t("chat.admin.export_messages.confirm_export"),
      didConfirm: () => this.exportMessages(),
    });
  }

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

  <template>
    <@actions.Primary
      @label="chat.admin.export_messages.create_export"
      @title="chat.admin.export_messages.create_export"
      @action={{this.confirmExportMessages}}
      @icon="right-from-bracket"
      class="admin-chat-export"
    />
  </template>
}
