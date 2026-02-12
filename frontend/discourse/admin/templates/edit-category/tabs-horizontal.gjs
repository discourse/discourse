import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import EditCategoryTab from "discourse/admin/components/edit-category-tab";
import BackButton from "discourse/components/back-button";
import BreadCrumbs from "discourse/components/bread-crumbs";
import DPageHeader from "discourse/components/d-page-header";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { registeredEditCategoryTabs } from "discourse/lib/edit-category-tabs";
import { and } from "discourse/truth-helpers";

export default class EditCategoryTabsHorizontalTemplate extends Component {
  evaluateTabCondition(tab, controller) {
    if (!tab.condition) {
      return true;
    }
    return tab.condition({
      category: controller.model,
      siteSettings: controller.siteSettings,
    });
  }

  <template>
    {{#if (and @controller.site.desktopView @controller.model.id)}}
      <BackButton
        @route="discovery.category"
        @model={{concat @controller.parentParams.slug "/" @controller.model.id}}
        @label="category.back"
      />
    {{/if}}
    <DPageHeader
      @titleLabel={{@controller.baseTitle}}
      @showDrawer={{true}}
      @collapseActionsOnMobile={{false}}
    >

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

          {{#each registeredEditCategoryTabs as |pluginTab|}}
            {{#if (this.evaluateTabCondition pluginTab @controller)}}
              <EditCategoryTab
                @panels={{@controller.panels}}
                @selectedTab={{@controller.selectedTab}}
                @params={{@controller.parentParams}}
                @tab={{pluginTab.id}}
                @tabTitle={{pluginTab.name}}
              />
            {{/if}}
          {{/each}}
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
  </template>
}
