import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

export default class DeleteRejectedUserModal extends Component {
  @action
  confirmDelete() {
    this.args.model.confirmDelete();
    this.args.closeModal();
  }

  <template>
    <DModal
      @bodyClass="delete-rejected-user"
      class="admin-delete-rejected-user-modal"
      @title={{i18n "review.user.delete_record.confirm_title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        <p>{{i18n "review.user.delete_record.confirm_body"}}</p>
      </:body>
      <:footer>
        <DButton
          class="btn btn-danger"
          @action={{this.confirmDelete}}
          @label={{"review.user.delete_record.confirm_button"}}
        />
        <DButton
          class="btn btn-default"
          @action={{@closeModal}}
          @label={{"review.user.delete_record.cancel_button"}}
        />
      </:footer>
    </DModal>
  </template>
}
