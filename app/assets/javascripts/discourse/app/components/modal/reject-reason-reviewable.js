import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class RejectReasonReviewableModal extends Component {
  rejectReason;
  sendEmail = false;

  @action
  async perform() {
    this.args.model.reviewable.setProperties({
      rejectReason: this.rejectReason,
      sendEmail: this.sendEmail,
    });
    this.args.closeModal();
    await this.args.model.performConfirmed(this.args.model.action);
  }
}
