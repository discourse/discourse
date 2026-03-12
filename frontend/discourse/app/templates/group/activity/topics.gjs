import BasicTopicList from "discourse/components/basic-topic-list";
import ConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import LoadMore from "discourse/ui-kit/d-load-more";

export default <template>
  <LoadMore @action={{@controller.loadMore}} class="paginated-topics-list">
    <BasicTopicList
      @topicList={{@controller.model}}
      @showPosters={{true}}
      @listContext="group-activity"
    />
    <ConditionalLoadingSpinner @condition={{@controller.model.loadingMore}} />
  </LoadMore>
</template>
