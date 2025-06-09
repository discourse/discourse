import RouteTemplate from "ember-route-template";
import { and } from "truth-helpers";
import CategoriesDisplay from "discourse/components/discovery/categories-display";
import Layout from "discourse/components/discovery/layout";
import Navigation from "discourse/components/discovery/navigation";
import Topics from "discourse/components/discovery/topics";
import TagInfo from "discourse/components/tag-info";

export default RouteTemplate(
  <template>
    <Layout
      @model={{@controller.model}}
      @createTopicDisabled={{@controller.createTopicDisabled}}
      @toggleTagInfo={{@controller.toggleTagInfo}}
    >
      <:navigation>
        <Navigation
          @category={{@controller.model.category}}
          @tag={{@controller.model.tag}}
          @additionalTags={{@controller.model.additionalTags}}
          @filterType={{@controller.model.filterType}}
          @noSubcategories={{@controller.model.noSubcategories}}
          @canBulkSelect={{@controller.canBulkSelect}}
          @bulkSelectHelper={{@controller.bulkSelectHelper}}
          @createTopic={{@controller.createTopic}}
          @createTopicDisabled={{@controller.createTopicDisabled}}
          @canCreateTopicOnTag={{@controller.model.canCreateTopicOnTag}}
          @toggleTagInfo={{@controller.toggleTagInfo}}
          @tagNotification={{@controller.model.tagNotification}}
          @model={{@controller.model.list}}
          @showDismissRead={{@controller.showDismissRead}}
          @showResetNew={{@controller.showResetNew}}
          @dismissRead={{@controller.dismissRead}}
          @resetNew={{@controller.resetNew}}
        />
      </:navigation>

      <:header>
        {{#if @controller.model.subcategoryList}}
          <CategoriesDisplay
            @categories={{@controller.model.subcategoryList.categories}}
            @parentCategory={{@controller.model.subcategoryList.parentCategory}}
            @loadMore={{@controller.model.subcategoryList.loadMore}}
          />
        {{/if}}
        {{#if (and @controller.showTagInfo @controller.model.tag)}}
          <TagInfo
            @tag={{@controller.model.tag}}
            @list={{@controller.model.list}}
          />
        {{/if}}
      </:header>

      <:list>
        <Topics
          @period={{@controller.model.list.for_period}}
          @changePeriod={{@controller.changePeriod}}
          @model={{@controller.model.list}}
          @canBulkSelect={{@controller.canBulkSelect}}
          @bulkSelectHelper={{@controller.bulkSelectHelper}}
          @showDismissRead={{@controller.showDismissRead}}
          @showResetNew={{@controller.showResetNew}}
          @category={{@controller.model.category}}
          @tag={{@controller.model.tag}}
          @changeSort={{@controller.changeSort}}
          @changeNewListSubset={{@controller.changeNewListSubset}}
          @dismissRead={{@controller.dismissRead}}
          @resetNew={{@controller.resetNew}}
        />
      </:list>
    </Layout>
  </template>
);
