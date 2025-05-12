import DModal from "discourse/components/d-modal";
import InvitePanel from "discourse/components/invite-panel";
import { i18n } from "discourse-i18n";

const AddPmParticipants = <template>
  <DModal
    @title={{i18n @model.title}}
    @closeModal={{@closeModal}}
    @bodyClass="invite modal-panel"
    class="add-pm-participants"
  >
    <:body>
      <InvitePanel
        @inviteModel={{@model.inviteModel}}
        @closeModal={{@closeModal}}
      />
    </:body>
  </DModal>
</template>;

export default AddPmParticipants;
