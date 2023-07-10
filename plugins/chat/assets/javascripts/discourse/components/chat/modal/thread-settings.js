import Component from "@glimmer/component";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class ChatModalThreadSettings extends Component {
  @service chatApi;

  @tracked editedTitle = this.thread.title || "";
  @tracked saving = false;

  get buttonDisabled() {
    return this.saving;
  }

  get thread() {
    return this.args.model;
  }

  @action
  saveThread() {
    this.saving = true;

    this.chatApi
      .editThread(this.thread.channel.id, this.thread.id, {
        title: this.editedTitle,
      })
      .then(() => {
        this.thread.title = this.editedTitle;
        this.args.closeModal();
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.saving = false;
      });
  }
}
