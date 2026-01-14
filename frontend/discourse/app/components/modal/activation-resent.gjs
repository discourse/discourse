import { htmlSafe } from "@ember/template";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

const ActivationResent = <template>
  <DModal @title={{i18n "log_in"}} @closeModal={{@closeModal}}>
    <:body>
      {{htmlSafe
        (i18n
          "login.sent_activation_email_again" currentEmail=@model.currentEmail
        )
      }}
    </:body>
  </DModal>
</template>;

export default ActivationResent;
