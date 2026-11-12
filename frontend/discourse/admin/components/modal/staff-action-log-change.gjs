import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class AdminStaffActionLogComponent extends Component {
  @tracked diff;

  constructor() {
    super(...arguments);
    this.loadDiff();
  }

  @action
  async loadDiff() {
    const diff = await ajax(
      `/admin/logs/staff_action_logs/${this.args.model.staffActionLog.id}/diff`
    );
    this.diff = diff.side_by_side;
  }

  <template>
    <DModal
      class="history-modal"
      @bodyClass="theme-change-modal-body"
      @closeModal={{@closeModal}}
      @title={{i18n "admin.logs.staff_actions.modal_title"}}
    >
      <:body>
        {{trustHTML this.diff}}
      </:body>
      <:footer>
        <DButton class="btn-primary" @action={{@closeModal}} @label="close" />
      </:footer>
    </DModal>
  </template>
}
