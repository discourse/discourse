import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import i18n from "discourse-common/helpers/i18n";
import I18n from "discourse-i18n";

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

  <template>
    <section class="admin-section">
      <h3>{{i18n "chat.admin.export_messages.title"}}</h3>
      <p>{{i18n "chat.admin.export_messages.description"}}</p>
      <DButton
        @label="chat.admin.export_messages.create_export"
        @title="chat.admin.export_messages.create_export"
        @action={{this.exportMessages}}
        class="btn-primary"
      />
    </section>
  </template>
}
