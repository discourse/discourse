import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import EditCategoryTab from "discourse/admin/components/edit-category-tab";
import BackButton from "discourse/components/back-button";
import BreadCrumbs from "discourse/components/bread-crumbs";
import { registeredEditCategoryTabs } from "discourse/lib/edit-category-tabs";
import { and } from "discourse/truth-helpers";
import DPageHeader from "discourse/ui-kit/d-page-header";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";

export default class EditCategoryTabsHorizontalTemplate extends Component {
  get dynamicCategoryTypeTabs() {
    return Object.values(this.args.controller.model.categoryTypes ?? {}).filter(
      (type) => type.id !== "discussion" && type.visible
    );
  }

  get visiblePrimaryTabs() {
    return registeredEditCategoryTabs.filter(
      (tab) =>
        tab.primary && this.evaluateTabCondition(tab, this.args.controller)
    );
  }

  get hasPrimaryTabs() {
    return (
      this.visiblePrimaryTabs.length > 0 ||
      this.dynamicCategoryTypeTabs.length > 0
    );
  }

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
        @label="category.back"
        @model={{concat @controller.parentParams.slug "/" @controller.model.id}}
        @route="discovery.category"
      />
    {{/if}}
    <DPageHeader
      ...attributes
      @collapseActionsOnMobile={{false}}
      @showDrawer={{true}}
      @titleLabel={{@controller.baseTitle}}
    >

      <:actions>
        <DToggleSwitch
          class="category-show-advanced-tabs-toggle"
          @label="category.show_advanced"
          @state={{@controller.showAdvancedTabs}}
          {{on "click" @controller.toggleAdvancedTabs}}
        />
      </:actions>
      <:tabs>
        {{#if @controller.showAdvancedTabs}}
          <EditCategoryTab
            @panels={{@controller.panels}}
            @params={{@controller.parentParams}}
            @selectedTab={{@controller.selectedTab}}
            @tab="general"
          />
          {{#each registeredEditCategoryTabs as |pluginTab|}}
            {{#if pluginTab.primary}}
              {{#if (this.evaluateTabCondition pluginTab @controller)}}
                <EditCategoryTab
                  @panels={{@controller.panels}}
                  @params={{@controller.parentParams}}
                  @selectedTab={{@controller.selectedTab}}
                  @tab={{pluginTab.id}}
                  @tabTitle={{pluginTab.name}}
                />
              {{/if}}
            {{/if}}
          {{/each}}
          {{#each this.dynamicCategoryTypeTabs as |dynamicTab|}}
            <EditCategoryTab
              @panels={{@controller.panels}}
              @params={{@controller.parentParams}}
              @selectedTab={{@controller.selectedTab}}
              @tab={{dynamicTab.id}}
              @tabTitle={{dynamicTab.name}}
            />
          {{/each}}
          <EditCategoryTab
            @panels={{@controller.panels}}
            @params={{@controller.parentParams}}
            @selectedTab={{@controller.selectedTab}}
            @tab="security"
          />
          <EditCategoryTab
            @panels={{@controller.panels}}
            @params={{@controller.parentParams}}
            @selectedTab={{@controller.selectedTab}}
            @tab="settings"
          />
          <EditCategoryTab
            @panels={{@controller.panels}}
            @params={{@controller.parentParams}}
            @selectedTab={{@controller.selectedTab}}
            @tab="moderation"
          />
          <EditCategoryTab
            @panels={{@controller.panels}}
            @params={{@controller.parentParams}}
            @selectedTab={{@controller.selectedTab}}
            @tab="images"
          />
          <EditCategoryTab
            @panels={{@controller.panels}}
            @params={{@controller.parentParams}}
            @selectedTab={{@controller.selectedTab}}
            @tab="topic-template"
          />
          {{#if @controller.siteSettings.tagging_enabled}}
            <EditCategoryTab
              @panels={{@controller.panels}}
              @params={{@controller.parentParams}}
              @selectedTab={{@controller.selectedTab}}
              @tab="tags"
            />
          {{/if}}

          {{#if @controller.siteSettings.content_localization_enabled}}
            <EditCategoryTab
              @panels={{@controller.panels}}
              @params={{@controller.parentParams}}
              @selectedTab={{@controller.selectedTab}}
              @tab="localizations"
            />
          {{/if}}

          {{#each registeredEditCategoryTabs as |pluginTab|}}
            {{#unless pluginTab.primary}}
              {{#if (this.evaluateTabCondition pluginTab @controller)}}
                <EditCategoryTab
                  @panels={{@controller.panels}}
                  @params={{@controller.parentParams}}
                  @selectedTab={{@controller.selectedTab}}
                  @tab={{pluginTab.id}}
                  @tabTitle={{pluginTab.name}}
                />
              {{/if}}
            {{/unless}}
          {{/each}}
        {{else if this.hasPrimaryTabs}}
          <EditCategoryTab
            @panels={{@controller.panels}}
            @params={{@controller.parentParams}}
            @selectedTab={{@controller.selectedTab}}
            @tab="general"
          />
          {{#each this.visiblePrimaryTabs as |pluginTab|}}
            <EditCategoryTab
              @panels={{@controller.panels}}
              @params={{@controller.parentParams}}
              @selectedTab={{@controller.selectedTab}}
              @tab={{pluginTab.id}}
              @tabTitle={{pluginTab.name}}
            />
          {{/each}}
          {{#each this.dynamicCategoryTypeTabs as |dynamicTab|}}
            <EditCategoryTab
              @panels={{@controller.panels}}
              @params={{@controller.parentParams}}
              @selectedTab={{@controller.selectedTab}}
              @tab={{dynamicTab.id}}
              @tabTitle={{dynamicTab.name}}
            />
          {{/each}}
        {{/if}}
      </:tabs>
      <:drawer>
        {{#if @controller.model.id}}
          <BreadCrumbs
            @categories={{@controller.breadcrumbCategories}}
            @category={{@controller.model}}
            @editingCategory={{true}}
            @editingCategoryTab={{@controller.selectedTab}}
            @noSubcategories={{@controller.model.noSubcategories}}
          />
        {{/if}}
      </:drawer>
    </DPageHeader>
  </template>
}
