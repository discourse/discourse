import RouteTemplate from "ember-route-template";
import BasicTopicList from "discourse/components/basic-topic-list";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";

export default RouteTemplate(
  <template>
    <LoadMore @action={{@controller.loadMore}} class="paginated-topics-list">
      <BasicTopicList @topicList={{@controller.model}} @showPosters={{true}} />
      <ConditionalLoadingSpinner @condition={{@controller.model.loadingMore}} />
    </LoadMore>
  </template>
);
