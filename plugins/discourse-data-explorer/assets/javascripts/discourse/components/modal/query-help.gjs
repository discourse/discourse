import { htmlSafe } from "@ember/template";
import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

const QueryHelp = <template>
  <DModal
    @title={{i18n "explorer.help.modal_title"}}
    @closeModal={{@closeModal}}
  >
    <:body>
      {{htmlSafe (i18n "explorer.help.auto_resolution")}}
      {{htmlSafe (i18n "explorer.help.custom_params")}}
      {{htmlSafe (i18n "explorer.help.default_values")}}
      {{htmlSafe (i18n "explorer.help.data_types")}}
    </:body>
  </DModal>
</template>;

export default QueryHelp;
