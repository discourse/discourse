import DButton from "discourse/ui-kit/d-button";

const BulkSelectToggle = <template>
  <DButton
    class="btn-default bulk-select"
    @action={{@bulkSelectHelper.toggleBulkSelect}}
    @title="topics.bulk.select"
    @icon="list"
  />
</template>;

export default BulkSelectToggle;
