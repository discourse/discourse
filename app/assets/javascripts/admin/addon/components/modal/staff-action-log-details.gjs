import DModal from "discourse/components/d-modal";
import i18n from "discourse/helpers/i18n";
import DButton from "discourse/components/d-button";
const StaffActionLogDetails = <template><DModal @title={{i18n "admin.logs.staff_actions.modal_title"}} @closeModal={{@closeModal}} class="log-details-modal">
  <:body>
    <pre>{{@model.staffActionLog.details}}</pre>
  </:body>
  <:footer>
    <DButton @action={{@closeModal}} @label="close" />
  </:footer>
</DModal></template>;
export default StaffActionLogDetails;