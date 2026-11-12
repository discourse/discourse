import DsaNoticeForm from "discourse/components/dsa-notice-form";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default <template>
  <DModal
    class="dsa-notice-modal"
    @closeModal={{@closeModal}}
    @submitOnEnter={{false}}
    @title={{i18n "dsa_notice.title"}}
  >
    <:body>
      <DsaNoticeForm
        @contentUrl={{@model.contentUrl}}
        @inModal={{true}}
        @onBack={{@model.onBack}}
        @onClose={{@closeModal}}
      />
    </:body>
  </DModal>
</template>
