import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

export default class UpdateDefaultTextSize extends Component {
  @action
  updateExistingUsers() {
    this.args.model.setUpdateExistingUsers(true);
    this.args.closeModal();
  }

  @action
  cancel() {
    this.args.model.setUpdateExistingUsers(null);
    this.args.closeModal();
  }

  <template>
    <DModal
      @title={{i18n "admin.config.fonts.backfill_modal.title"}}
      @closeModal={{@closeModal}}
    >
      <:body>
        {{i18n
          "admin.config.fonts.backfill_modal.description"
          count=@model.count
        }}
      </:body>
      <:footer>
        <DButton
          @action={{this.updateExistingUsers}}
          @label="admin.config.fonts.backfill_modal.modal_yes"
          class="btn-primary"
        />
        <DButton
          @action={{this.cancel}}
          @label="admin.config.fonts.backfill_modal.modal_no"
        />
      </:footer>
    </DModal>
  </template>
}
