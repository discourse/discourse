<LoadMore
  @selector=".paginated-topics-list .topic-list tr"
  @action={{action "loadMore"}}
  class="paginated-topics-list"
>
  <BasicTopicList @topicList={{this.model}} @showPosters={{true}} />
  <ConditionalLoadingSpinner @condition={{this.model.loadingMore}} />
</LoadMore>