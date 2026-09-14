import CategoriesDisplay from "discourse/components/discovery/categories-display";
import Layout from "discourse/components/discovery/layout";
import Navigation from "discourse/components/discovery/navigation";
import Topics from "discourse/components/discovery/topics";
import TagInfo from "discourse/components/tag-info";
import { and } from "discourse/truth-helpers";

export default <template>
  <Layout
    @createTopicDisabled={{@controller.createTopicDisabled}}
    @listClass="--topic-list"
    @model={{@controller.model}}
    @toggleTagInfo={{@controller.toggleTagInfo}}
  >
    <:aboveNavigation>
      {{#if (and @controller.model.tag @controller.showTagInfo)}}
        <TagInfo
          @currentUser={{@controller.currentUser}}
          @loading={{@controller.loadingTagInfo}}
          @tagInfo={{@controller.tagInfo}}
        />
      {{/if}}
    </:aboveNavigation>

    <:navigation>
      <Navigation
        @additionalTags={{@controller.model.additionalTags}}
        @bulkSelectHelper={{@controller.bulkSelectHelper}}
        @canBulkSelect={{@controller.canBulkSelect}}
        @canCreateTopicOnTag={{@controller.model.canCreateTopicOnTag}}
        @category={{@controller.model.category}}
        @createTopic={{@controller.createTopic}}
        @createTopicDisabled={{@controller.createTopicDisabled}}
        @dismissRead={{@controller.dismissRead}}
        @filterType={{@controller.model.filterType}}
        @loadingTagInfo={{@controller.loadingTagInfo}}
        @model={{@controller.model.list}}
        @noSubcategories={{@controller.model.noSubcategories}}
        @resetNew={{@controller.resetNew}}
        @showDismissRead={{@controller.showDismissRead}}
        @showResetNew={{@controller.showResetNew}}
        @showTagInfo={{@controller.showTagInfo}}
        @tag={{@controller.model.tag}}
        @tagNotification={{@controller.model.tagNotification}}
        @toggleTagInfo={{@controller.toggleTagInfo}}
      />
    </:navigation>

    <:header>
      {{#if @controller.model.subcategoryList.content}}
        <CategoriesDisplay
          @categories={{@controller.model.subcategoryList.content}}
          @loadMore={{@controller.model.subcategoryList.loadMore}}
          @parentCategory={{@controller.model.subcategoryList.parentCategory}}
        />
      {{/if}}
    </:header>

    <:list>
      <Topics
        @bulkSelectHelper={{@controller.bulkSelectHelper}}
        @canBulkSelect={{@controller.canBulkSelect}}
        @category={{@controller.model.category}}
        @changeNewListSubset={{@controller.changeNewListSubset}}
        @changePeriod={{@controller.changePeriod}}
        @changeSort={{@controller.changeSort}}
        @dismissRead={{@controller.dismissRead}}
        @model={{@controller.model.list}}
        @period={{@controller.model.list.for_period}}
        @resetNew={{@controller.resetNew}}
        @showDismissRead={{@controller.showDismissRead}}
        @showResetNew={{@controller.showResetNew}}
        @tag={{@controller.model.tag}}
      />
    </:list>
  </Layout>
</template>
