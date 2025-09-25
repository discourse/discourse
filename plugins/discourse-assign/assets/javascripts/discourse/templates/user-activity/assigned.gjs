import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import BasicTopicList from "discourse/components/basic-topic-list";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import EmptyState from "discourse/components/empty-state";
import LoadMore from "discourse/components/load-more";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    {{#if @controller.doesntHaveAssignments}}
      <EmptyState
        @title={{i18n "user.no_assignments_title"}}
        @body={{@controller.emptyStateBody}}
      />
    {{else}}
      <div class="topic-search-div">
        <div class="inline-form full-width">
          <Input
            {{on "input" (withEventValue @controller.onChangeFilter)}}
            @value={{readonly @controller.search}}
            @type="search"
            placeholder={{i18n "discourse_assign.topic_search_placeholder"}}
            autocomplete="off"
            class="no-blur"
          />
        </div>
      </div>

      <LoadMore
        @selector=".paginated-topics-list .topic-list tr"
        @action={{@controller.loadMore}}
        class="paginated-topics-list"
      >
        <BasicTopicList
          @topicList={{@controller.model}}
          @hideCategory={{@controller.hideCategory}}
          @showPosters={{true}}
          @bulkSelectEnabled={{@controller.bulkSelectEnabled}}
          @selected={{@controller.selected}}
          @hasIncoming={{@controller.hasIncoming}}
          @incomingCount={{@controller.incomingCount}}
          @showInserted={{@controller.showInserted}}
          @tagsForUser={{@controller.tagsForUser}}
          @changeSort={{@controller.changeSort}}
          @unassign={{@controller.unassign}}
          @reassign={{@controller.reassign}}
          @onScroll={{@controller.saveScrollPosition}}
          @scrollOnLoad={{true}}
        />

        <ConditionalLoadingSpinner
          @condition={{@controller.model.loadingMore}}
        />
      </LoadMore>
    {{/if}}
  </template>
);
