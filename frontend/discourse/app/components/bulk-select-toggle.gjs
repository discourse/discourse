import DButton from "discourse/ui-kit/d-button";

const BulkSelectToggle = <template>
  <DButton
    class="btn-default bulk-select"
    @action={{@bulkSelectHelper.toggleBulkSelect}}
    @icon="list"
    @title="topics.bulk.select"
  />
</template>;

export default BulkSelectToggle;
