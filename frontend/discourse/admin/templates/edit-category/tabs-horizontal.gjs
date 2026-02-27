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

  get visiblePrimaryTabs() {
    return registeredEditCategoryTabs.filter(
      (tab) =>
        tab.primary && this.evaluateTabCondition(tab, this.args.controller)
    );
  }

  get hasPrimaryTabs() {
    return this.visiblePrimaryTabs.length > 0;
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
            @selectedTab={{@controller.selectedTab}}
            @params={{@controller.parentParams}}
            @tab="general"
          />
          {{#each registeredEditCategoryTabs as |pluginTab|}}
            {{#if pluginTab.primary}}
              {{#if (this.evaluateTabCondition pluginTab @controller)}}
                <EditCategoryTab
                  @panels={{@controller.panels}}
                  @selectedTab={{@controller.selectedTab}}
                  @params={{@controller.parentParams}}
                  @tab={{pluginTab.id}}
                  @tabTitle={{pluginTab.name}}
                />
              {{/if}}
            {{/if}}
          {{/each}}
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
            {{#unless pluginTab.primary}}
              {{#if (this.evaluateTabCondition pluginTab @controller)}}
                <EditCategoryTab
                  @panels={{@controller.panels}}
                  @selectedTab={{@controller.selectedTab}}
                  @params={{@controller.parentParams}}
                  @tab={{pluginTab.id}}
                  @tabTitle={{pluginTab.name}}
                />
              {{/if}}
            {{/unless}}
          {{/each}}
        {{else if this.hasPrimaryTabs}}
          <EditCategoryTab
            @panels={{@controller.panels}}
            @selectedTab={{@controller.selectedTab}}
            @params={{@controller.parentParams}}
            @tab="general"
          />
          {{#each this.visiblePrimaryTabs as |pluginTab|}}
            <EditCategoryTab
              @panels={{@controller.panels}}
              @selectedTab={{@controller.selectedTab}}
              @params={{@controller.parentParams}}
              @tab={{pluginTab.id}}
              @tabTitle={{pluginTab.name}}
            />
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
