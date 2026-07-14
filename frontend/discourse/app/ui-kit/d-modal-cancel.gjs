import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const DModalCancel = <template>
  <DButton
    @action={{@close}}
    @translatedLabel={{i18n "cancel"}}
    class="btn-flat d-modal-cancel"
  />
</template>;

export default DModalCancel;
