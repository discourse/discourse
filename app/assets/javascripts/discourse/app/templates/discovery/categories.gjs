import { on } from "@ember/modifier";
import RouteTemplate from "ember-route-template";
import { and } from "truth-helpers";
import CountI18n from "discourse/components/count-i18n";
import CategoriesDisplay from "discourse/components/discovery/categories-display";
import Layout from "discourse/components/discovery/layout";
import Navigation from "discourse/components/discovery/navigation";
import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import concatClass from "discourse/helpers/concat-class";
import lazyHash from "discourse/helpers/lazy-hash";

export default RouteTemplate(
  <template>
    <Layout @model={{@controller.model}}>
      <:navigation>
        <Navigation
          @category={{@controller.model.parentCategory}}
          @showCategoryAdmin={{@controller.model.can_create_category}}
          @canCreateTopic={{@controller.model.can_create_topic}}
          @createTopic={{@controller.createTopic}}
          @filterType="categories"
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
              class={{concatClass
                "show-more"
                (if @controller.hasTopics "has-topics")
              }}
            >
              <div
                role="button"
                class="alert alert-info clickable"
                {{on "click" @controller.showInserted}}
              >
                <CountI18n
                  @key="topic_count_"
                  @suffix={{@controller.topicTrackingState.filter}}
                  @count={{@controller.topicTrackingState.incomingCount}}
                />
              </div>
            </div>
          {{/if}}

          <CategoriesDisplay
            @categories={{@controller.model.categories}}
            @topics={{@controller.model.topics}}
            @parentCategory={{@controller.model.parentCategory}}
            @loadMore={{@controller.model.loadMore}}
            @loadingMore={{@controller.model.isLoading}}
          />
        </div>

        <PluginOutlet
          @name="below-discovery-categories"
          @connectorTagName="div"
          @outletArgs={{lazyHash
            categories=@controller.model.categories
            topics=@controller.model.topics
          }}
        />
      </:list>
    </Layout>
  </template>
);
