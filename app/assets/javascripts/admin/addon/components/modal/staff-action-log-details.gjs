import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

const StaffActionLogDetails = <template>
  <DModal
    @title={{i18n "admin.logs.staff_actions.modal_title"}}
    @closeModal={{@closeModal}}
    class="log-details-modal"
  >
    <:body>
      <pre>{{@model.staffActionLog.details}}</pre>
    </:body>
    <:footer>
      <DButton @action={{@closeModal}} @label="close" />
    </:footer>
  </DModal>
</template>;

export default StaffActionLogDetails;
