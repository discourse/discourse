import type { TOC } from "@ember/component/template-only";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

interface DModalCancelSignature {
  Args: {
    /** Closes the modal. Called when the button is pressed. */
    close: () => void;
  };
}

const DModalCancel: TOC<DModalCancelSignature> = <template>
  <DButton
    class="btn-flat d-modal-cancel"
    @action={{@close}}
    @translatedLabel={{i18n "cancel"}}
  />
</template>;

export default DModalCancel;
