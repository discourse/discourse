import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import BasicTopicList from "discourse/components/basic-topic-list";
import withEventValue from "discourse/helpers/with-event-value";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import DLoadMore from "discourse/ui-kit/d-load-more";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @controller.hasAssignments}}
    <div class="topic-search-div">
      <div class="inline-form full-width">
        <Input
          autocomplete="off"
          class="no-blur"
          placeholder={{i18n "discourse_assign.topic_search_placeholder"}}
          @type="search"
          @value={{readonly @controller.search}}
          {{on "input" (withEventValue @controller.onChangeFilter)}}
        />
      </div>
    </div>

    <DLoadMore
      class="paginated-topics-list"
      @action={{@controller.loadMore}}
      @selector=".paginated-topics-list .topic-list tr"
    >
      <BasicTopicList
        @bulkSelectAction={{@controller.refresh}}
        @bulkSelectEnabled={{@controller.bulkSelectEnabled}}
        @bulkSelectHelper={{@controller.bulkSelectHelper}}
        @canBulkSelect={{@controller.canBulkSelect}}
        @changeSort={{@controller.changeSort}}
        @hasIncoming={{@controller.hasIncoming}}
        @hideCategory={{@controller.hideCategory}}
        @incomingCount={{@controller.incomingCount}}
        @listContext="assigned"
        @onScroll={{@controller.saveScrollPosition}}
        @reassign={{@controller.reassign}}
        @scrollOnLoad={{true}}
        @selected={{@controller.selected}}
        @showInserted={{@controller.showInserted}}
        @showPosters={{@controller.showPosters}}
        @tagsForUser={{@controller.tagsForUser}}
        @toggleBulkSelect={{@controller.toggleBulkSelect}}
        @topicList={{@controller.model}}
        @unassign={{@controller.unassign}}
      />

      <DConditionalLoadingSpinner
        @condition={{@controller.model.loadingMore}}
      />
    </DLoadMore>
  {{else}}
    <DEmptyState
      @body={{i18n "discourse_assign.group_no_assignments_body"}}
      @title={{i18n "discourse_assign.group_no_assignments_title"}}
    />
  {{/if}}
</template>
