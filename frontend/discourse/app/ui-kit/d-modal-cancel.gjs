import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const DModalCancel = <template>
  <DButton
    class="btn-flat d-modal-cancel"
    @action={{@close}}
    @translatedLabel={{i18n "cancel"}}
  />
</template>;

export default DModalCancel;
