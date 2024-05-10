{{#if this.model.canLoadMore}}
  {{hide-application-footer}}
{{/if}}

{{#if this.noContent}}
  <EmptyState
    @title={{this.model.emptyState.title}}
    @body={{this.model.emptyState.body}}
  />
{{else}}
  <LoadMore
    @selector=".paginated-topics-list .topic-list .topic-list-item"
    @action={{action "loadMore"}}
    class="paginated-topics-list"
  >
    <TopicDismissButtons
      @position="top"
      @selectedTopics={{this.bulkSelectHelper.selected}}
      @model={{this.model}}
      @showResetNew={{this.showResetNew}}
      @showDismissRead={{this.showDismissRead}}
      @resetNew={{action "resetNew"}}
      @dismissRead={{if
        this.showDismissRead
        (route-action "dismissReadTopics")
      }}
    />

    {{#if (or this.model.loadingBefore this.incomingCount)}}
      <div class="show-mores">
        <a
          tabindex="0"
          href
          {{on "click" this.showInserted}}
          class="alert alert-info clickable
            {{if this.model.loadingBefore 'loading'}}"
        >
          <CountI18n
            @key="topic_count_latest"
            @count={{or this.model.loadingBefore this.incomingCount}}
          />
          {{#if @model.loadingBefore}}
            {{loading-spinner size="small"}}
          {{/if}}
        </a>
      </div>
    {{/if}}

    <BasicTopicList
      @topicList={{this.model}}
      @hideCategory={{this.hideCategory}}
      @showPosters={{this.showPosters}}
      @tagsForUser={{this.tagsForUser}}
      @canBulkSelect={{this.canBulkSelect}}
      @bulkSelectHelper={{this.bulkSelectHelper}}
      @changeSort={{this.changeSort}}
      @order={{this.order}}
      @ascending={{this.ascending}}
      @focusLastVisitedTopic={{true}}
    />

    <TopicDismissButtons
      @position="bottom"
      @selectedTopics={{this.bulkSelectHelper.selected}}
      @model={{this.model}}
      @showResetNew={{this.showResetNew}}
      @showDismissRead={{this.showDismissRead}}
      @resetNew={{action "resetNew"}}
      @dismissRead={{if
        this.showDismissRead
        (route-action "dismissReadTopics")
      }}
    />

    <ConditionalLoadingSpinner @condition={{this.model.loadingMore}} />
  </LoadMore>
{{/if}}