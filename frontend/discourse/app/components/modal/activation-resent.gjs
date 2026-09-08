import { trustHTML } from "@ember/template";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const ActivationResent = <template>
  <DModal @closeModal={{@closeModal}} @title={{i18n "log_in"}}>
    <:body>
      {{trustHTML
        (i18n
          "login.sent_activation_email_again" currentEmail=@model.currentEmail
        )
      }}
    </:body>
  </DModal>
</template>;

export default ActivationResent;
