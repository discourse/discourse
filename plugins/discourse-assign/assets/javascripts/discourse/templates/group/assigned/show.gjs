import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import BasicTopicList from "discourse/components/basic-topic-list";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
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
        @showPosters={{@controller.showPosters}}
        @bulkSelectEnabled={{@controller.bulkSelectEnabled}}
        @canBulkSelect={{@controller.canBulkSelect}}
        @selected={{@controller.selected}}
        @hasIncoming={{@controller.hasIncoming}}
        @incomingCount={{@controller.incomingCount}}
        @showInserted={{@controller.showInserted}}
        @tagsForUser={{@controller.tagsForUser}}
        @changeSort={{@controller.changeSort}}
        @toggleBulkSelect={{@controller.toggleBulkSelect}}
        @bulkSelectAction={{@controller.refresh}}
        @bulkSelectHelper={{@controller.bulkSelectHelper}}
        @unassign={{@controller.unassign}}
        @reassign={{@controller.reassign}}
        @onScroll={{@controller.saveScrollPosition}}
        @scrollOnLoad={{true}}
      />

      <ConditionalLoadingSpinner @condition={{@controller.model.loadingMore}} />
    </LoadMore>
  </template>
);
