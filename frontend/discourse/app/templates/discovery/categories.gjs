import { on } from "@ember/modifier";
import CategoriesDisplay from "discourse/components/discovery/categories-display";
import Layout from "discourse/components/discovery/layout";
import Navigation from "discourse/components/discovery/navigation";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import lazyHash from "discourse/helpers/lazy-hash";
import { and } from "discourse/truth-helpers";
import DCountI18n from "discourse/ui-kit/d-count-i18n";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default <template>
  <Layout @listClass="--categories" @model={{@controller.model}}>
    <:navigation>
      <Navigation
        @canCreateTopic={{@controller.model.can_create_topic}}
        @category={{@controller.model.parentCategory}}
        @createTopic={{@controller.createTopic}}
        @filterType="categories"
        @showCategoryAdmin={{@controller.model.can_create_category}}
      />
    </:navigation>
    <:list>

      {{bodyClass "categories-list"}}

      <div class="contents">
        {{#if
          (and
            @controller.topicTrackingState.hasIncoming
            @controller.isCategoriesRoute
          )
        }}
          <div
            class={{dConcatClass
              "show-more"
              (if @controller.hasTopics "has-topics")
            }}
          >
            <div
              class="alert alert-info clickable"
              role="button"
              {{on "click" @controller.showInserted}}
            >
              <DCountI18n
                @count={{@controller.topicTrackingState.incomingCount}}
                @key="topic_count_"
                @suffix={{@controller.topicTrackingState.filter}}
              />
            </div>
          </div>
        {{/if}}

        <CategoriesDisplay
          @categories={{@controller.model.content}}
          @loadingMore={{@controller.model.isLoading}}
          @loadMore={{@controller.model.loadMore}}
          @parentCategory={{@controller.model.parentCategory}}
          @topics={{@controller.model.topics}}
        />
      </div>

      <PluginOutlet
        @connectorTagName="div"
        @name="below-discovery-categories"
        @outletArgs={{lazyHash
          categories=@controller.model.content
          topics=@controller.model.topics
        }}
      />
    </:list>
  </Layout>
</template>
