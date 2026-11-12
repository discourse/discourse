import { trustHTML } from "@ember/template";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const QueryHelp = <template>
  <DModal
    @closeModal={{@closeModal}}
    @title={{i18n "explorer.help.modal_title"}}
  >
    <:body>
      {{trustHTML (i18n "explorer.help.auto_resolution")}}
      {{trustHTML (i18n "explorer.help.custom_params")}}
      {{trustHTML (i18n "explorer.help.default_values")}}
      {{trustHTML (i18n "explorer.help.data_types")}}
    </:body>
  </DModal>
</template>;

export default QueryHelp;
