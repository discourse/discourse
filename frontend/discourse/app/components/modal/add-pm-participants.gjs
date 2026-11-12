import InvitePanel from "discourse/components/invite-panel";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const AddPmParticipants = <template>
  <DModal
    class="add-pm-participants"
    @bodyClass="invite modal-panel"
    @closeModal={{@closeModal}}
    @title={{i18n @model.title}}
  >
    <:body>
      <InvitePanel
        @closeModal={{@closeModal}}
        @inviteModel={{@model.inviteModel}}
      />
    </:body>
  </DModal>
</template>;

export default AddPmParticipants;
