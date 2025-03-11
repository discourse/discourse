import DModal from "discourse/components/d-modal";
import i18n from "discourse/helpers/i18n";
import InvitePanel from "discourse/components/invite-panel";
const AddPmParticipants = <template><DModal @title={{i18n @model.title}} @closeModal={{@closeModal}} @bodyClass="invite modal-panel" class="add-pm-participants">
  <:body>
    <InvitePanel @inviteModel={{@model.inviteModel}} @closeModal={{@closeModal}} />
  </:body>
</DModal></template>;
export default AddPmParticipants;