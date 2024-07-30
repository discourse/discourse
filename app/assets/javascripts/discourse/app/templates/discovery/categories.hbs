<Discovery::Layout @model={{this.model}}>
  <:navigation>
    <Discovery::Navigation
      @category={{this.model.parentCategory}}
      @showCategoryAdmin={{this.model.can_create_category}}
      @canCreateTopic={{this.model.can_create_topic}}
      @createTopic={{this.createTopic}}
      @filterType="categories"
    />
  </:navigation>
  <:list>

    {{body-class "categories-list"}}

    <div class="contents">
      {{#if (and this.topicTrackingState.hasIncoming this.isCategoriesRoute)}}
        <div
          class={{concat-class "show-more" (if this.hasTopics "has-topics")}}
        >
          <div
            role="button"
            class="alert alert-info clickable"
            {{on "click" this.showInserted}}
          >
            <CountI18n
              @key="topic_count_"
              @suffix={{this.topicTrackingState.filter}}
              @count={{this.topicTrackingState.incomingCount}}
            />
          </div>
        </div>
      {{/if}}

      <Discovery::CategoriesDisplay
        @categories={{this.model.categories}}
        @topics={{this.model.topics}}
        @parentCategory={{this.model.parentCategory}}
        @loadMore={{this.model.loadMore}}
        @loadingMore={{this.model.isLoading}}
      />
    </div>

    <PluginOutlet
      @name="below-discovery-categories"
      @connectorTagName="div"
      @outletArgs={{hash
        categories=this.model.categories
        topics=this.model.topics
      }}
    />
  </:list>
</Discovery::Layout>