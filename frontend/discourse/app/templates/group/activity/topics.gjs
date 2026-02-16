import BasicTopicList from "discourse/components/basic-topic-list";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";

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
