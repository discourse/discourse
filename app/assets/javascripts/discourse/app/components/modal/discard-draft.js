import { action } from "@ember/object";
import Component from "@glimmer/component";

export default class DiscardDraftModal extends Component {
  @action
  async discardDraft() {
    await this.args.model.onDestroyDraft();
    this.args.closeModal();
  }

  @action
  async saveDraftAndClose() {
    await this.args.model.onSaveDraft();
    this.args.closeModal();
  }
}
