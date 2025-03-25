import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import htmlSafe from "discourse/helpers/html-safe";
import { ajax } from "discourse/lib/ajax";
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
      @title={{i18n "admin.logs.staff_actions.modal_title"}}
      @closeModal={{@closeModal}}
      @bodyClass="theme-change-modal-body"
      class="history-modal"
    >
      <:body>
        {{htmlSafe this.diff}}
      </:body>
      <:footer>
        <DButton class="btn-primary" @action={{@closeModal}} @label="close" />
      </:footer>
    </DModal>
  </template>
}
