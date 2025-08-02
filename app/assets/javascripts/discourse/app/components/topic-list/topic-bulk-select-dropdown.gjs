import BulkSelectTopicsDropdown from "discourse/components/bulk-select-topics-dropdown";
import { i18n } from "discourse-i18n";

const TopicBulkSelectDropdown = <template>
  <div class="bulk-select-topics-dropdown">
    <span class="bulk-select-topic-dropdown__count">
      {{i18n
        "topics.bulk.selected_count"
        count=@bulkSelectHelper.selected.length
      }}
    </span>
    <BulkSelectTopicsDropdown
      @bulkSelectHelper={{@bulkSelectHelper}}
      @afterBulkActionComplete={{@afterBulkActionComplete}}
    />
  </div>
</template>;

export default TopicBulkSelectDropdown;
