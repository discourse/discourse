import Component from "@glimmer/component";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ChatThreadSettingsModalInner extends Component {
  @service chatApi;

  @tracked editedTitle = this.args.thread.title || "";
  @tracked saving = false;

  get buttonDisabled() {
    return this.saving;
  }

  @action
  saveThread() {
    this.saving = true;
    this.chatApi
      .editThread(this.args.thread.channel.id, this.args.thread.id, {
        title: this.editedTitle,
      })
      .then(() => {
        this.args.thread.title = this.editedTitle;
        this.args.closeModal();
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.saving = false;
      });
  }
}
