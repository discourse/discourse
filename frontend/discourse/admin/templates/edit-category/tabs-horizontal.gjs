import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import EditCategoryTab from "discourse/admin/components/edit-category-tab";
import BreadCrumbs from "discourse/components/bread-crumbs";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { and } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const EditCategoryTabsHorizontalTemplate = <template>
  <DPageHeader
    @titleLabel={{@controller.baseTitle}}
    @showDrawer={{true}}
    @collapseActionsOnMobile={{false}}
  >
    <:breadcrumbs>
      {{#if (and @controller.site.desktopView @controller.model.id)}}
        <DBreadcrumbsItem
          @path={{concat "/c/" @controller.model.slug}}
          @label={{i18n "category.back"}}
        />
      {{/if}}
    </:breadcrumbs>
    <:actions>
      <DToggleSwitch
        @label="category.show_advanced"
        @state={{@controller.showAdvancedTabs}}
        {{on "click" @controller.toggleAdvancedTabs}}
      />
    </:actions>
    <:tabs>
      {{#if @controller.showAdvancedTabs}}
        <EditCategoryTab
          @panels={{@controller.panels}}
          @selectedTab={{@controller.selectedTab}}
          @params={{@controller.parentParams}}
          @tab="general"
        />
        <EditCategoryTab
          @panels={{@controller.panels}}
          @selectedTab={{@controller.selectedTab}}
          @params={{@controller.parentParams}}
          @tab="security"
        />
        <EditCategoryTab
          @panels={{@controller.panels}}
          @selectedTab={{@controller.selectedTab}}
          @params={{@controller.parentParams}}
          @tab="settings"
        />
        <EditCategoryTab
          @panels={{@controller.panels}}
          @selectedTab={{@controller.selectedTab}}
          @params={{@controller.parentParams}}
          @tab="images"
        />
        <EditCategoryTab
          @panels={{@controller.panels}}
          @selectedTab={{@controller.selectedTab}}
          @params={{@controller.parentParams}}
          @tab="topic-template"
        />
        {{#if @controller.siteSettings.tagging_enabled}}
          <EditCategoryTab
            @panels={{@controller.panels}}
            @selectedTab={{@controller.selectedTab}}
            @params={{@controller.parentParams}}
            @tab="tags"
          />
        {{/if}}

        {{#if @controller.siteSettings.content_localization_enabled}}
          <EditCategoryTab
            @panels={{@controller.panels}}
            @selectedTab={{@controller.selectedTab}}
            @params={{@controller.parentParams}}
            @tab="localizations"
          />
        {{/if}}
      {{/if}}
    </:tabs>
    <:drawer>
      {{#if @controller.model.id}}
        <BreadCrumbs
          @categories={{@controller.breadcrumbCategories}}
          @category={{@controller.model}}
          @noSubcategories={{@controller.model.noSubcategories}}
          @editingCategory={{true}}
          @editingCategoryTab={{@controller.selectedTab}}
        />
      {{/if}}
    </:drawer>
  </DPageHeader>
</template>;

export default EditCategoryTabsHorizontalTemplate;
