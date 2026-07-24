import BasicTopicList from "discourse/components/basic-topic-list";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";

export default <template>
  <DLoadMore @action={{@controller.loadMore}} class="paginated-topics-list">
    <BasicTopicList
      @topicList={{@controller.model}}
      @showPosters={{true}}
      @listContext="group-activity"
    />
    <DConditionalLoadingSpinner @condition={{@controller.model.loadingMore}} />
  </DLoadMore>
</template>
