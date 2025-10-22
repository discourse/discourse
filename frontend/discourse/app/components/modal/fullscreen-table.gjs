import DModal from "discourse/components/d-modal";
import { i18n } from "discourse-i18n";

const FullscreenTable = <template>
  <DModal
    @title={{i18n "fullscreen_table.view_table"}}
    @closeModal={{@closeModal}}
    class="fullscreen-table-modal -max"
  >
    <:body>
      {{@model.tableHtml}}
    </:body>
  </DModal>
</template>;

export default FullscreenTable;
