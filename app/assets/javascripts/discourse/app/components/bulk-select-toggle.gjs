import DButton from "discourse/components/d-button";
import bodyClass from "discourse/helpers/body-class";

const BulkSelectToggle = <template>
  {{bodyClass (if @bulkSelectHelper.bulkSelectEnabled "bulk-select-enabled")}}
  <DButton
    class="btn-default bulk-select"
    @action={{@bulkSelectHelper.toggleBulkSelect}}
    @icon="list"
  />
</template>;

export default BulkSelectToggle;
