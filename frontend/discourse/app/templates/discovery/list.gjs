import CategoriesDisplay from "discourse/components/discovery/categories-display";
import Layout from "discourse/components/discovery/layout";
import Navigation from "discourse/components/discovery/navigation";
import Topics from "discourse/components/discovery/topics";
import TagInfo from "discourse/components/tag-info";
import { and } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default <template>
  <Layout
    @model={{@controller.model}}
    @createTopicDisabled={{@controller.createTopicDisabled}}
    @toggleTagInfo={{@controller.toggleTagInfo}}
    @listClass="--topic-list"
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
      {{#if @controller.model.subcategoryList.content}}
        <CategoriesDisplay
          @categories={{@controller.model.subcategoryList.content}}
          @parentCategory={{@controller.model.subcategoryList.parentCategory}}
          @loadMore={{@controller.model.subcategoryList.loadMore}}
        />
      {{/if}}
      {{#unless @controller.siteSettings.experimental_tag_settings_page}}
        {{#if (and @controller.model.tag @controller.showTagInfo)}}
          <TagInfo
            @tag={{@controller.model.tag}}
            @list={{@controller.model.list}}
          />
        {{/if}}
      {{/unless}}
    </:header>

    <:list>
      {{#if @controller.showFakeUpcomingChange}}
        {{i18n "user.upcoming_changes.title"}}
      {{/if}}

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
