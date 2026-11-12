import BasicTopicList from "discourse/components/basic-topic-list";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";

export default <template>
  <DLoadMore class="paginated-topics-list" @action={{@controller.loadMore}}>
    <BasicTopicList
      @listContext="group-activity"
      @showPosters={{true}}
      @topicList={{@controller.model}}
    />
    <DConditionalLoadingSpinner @condition={{@controller.model.loadingMore}} />
  </DLoadMore>
</template>
