import Component from "@glimmer/component";
import { action } from "@ember/object";

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
