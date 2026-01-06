import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { htmlSafe } from "@ember/template";
import EditCategoryGeneral from "discourse/admin/components/edit-category-general";
import EditCategoryImages from "discourse/admin/components/edit-category-images";
import EditCategoryLocalizations from "discourse/admin/components/edit-category-localizations";
import EditCategorySecurity from "discourse/admin/components/edit-category-security";
import EditCategorySettings from "discourse/admin/components/edit-category-settings";
import EditCategoryTab from "discourse/admin/components/edit-category-tab";
import EditCategoryTags from "discourse/admin/components/edit-category-tags";
import EditCategoryTopicTemplate from "discourse/admin/components/edit-category-topic-template";
import BreadCrumbs from "discourse/components/bread-crumbs";
import DButton from "discourse/components/d-button";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import Form from "discourse/components/form";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import { and, not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const TAB_COMPONENTS = {
  general: EditCategoryGeneral,
  security: EditCategorySecurity,
  settings: EditCategorySettings,
  images: EditCategoryImages,
  "topic-template": EditCategoryTopicTemplate,
  tags: EditCategoryTags,
  localizations: EditCategoryLocalizations,
};

function componentFor(name) {
  name = name.replace("edit-category-", "");

  if (!TAB_COMPONENTS[name]) {
    throw new Error(`No category-tab component found for tab name: ${name}`);
  }
  return TAB_COMPONENTS[name];
}

export default <template>
  <div class="edit-category {{if @controller.expandedMenu 'expanded-menu'}}">
    <div class="edit-category-title-bar">
      <div class="edit-category-title">
        {{#if (and @controller.site.desktopView @controller.model.id)}}
          <DButton
            @action={{@controller.goBack}}
            @label="category.back"
            @icon="chevron-left"
            class="btn-transparent btn-back"
          />
        {{/if}}
        <h2>{{@controller.title}}</h2>
        {{#if @controller.model.id}}
          <BreadCrumbs
            @categories={{@controller.breadcrumbCategories}}
            @category={{@controller.model}}
            @noSubcategories={{@controller.model.noSubcategories}}
            @editingCategory={{true}}
            @editingCategoryTab={{@controller.selectedTab}}
          />
        {{/if}}

      </div>
      <div class="edit-category-title-bar-actions">
        <label class="advanced-toggle-label">
          {{i18n "category.show_advanced"}}
          <DToggleSwitch
            @state={{@controller.showAdvancedTabs}}
            {{on "click" @controller.toggleAdvancedTabs}}
          />
        </label>

      </div>
    </div>

    {{#if @controller.showAdvancedTabs}}
      <HorizontalOverflowNav
        @ariaLabel="Category navigation"
        class="edit-category-nav"
      >
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
      </HorizontalOverflowNav>
    {{/if}}

    <Form
      @data={{@controller.formData}}
      @onDirtyCheck={{@controller.isLeavingForm}}
      @onSubmit={{@controller.saveCategory}}
      as |form transientData|
    >
      <form.Section
        class="edit-category-content edit-category-tab-{{@controller.selectedTab}}"
      >
        {{#let
          (componentFor (concat "edit-category-" @controller.selectedTab))
          as |Tab|
        }}
          <Tab
            @selectedTab={{@controller.selectedTab}}
            @category={{@controller.model}}
            @registerValidator={{@controller.registerValidator}}
            @transientData={{transientData}}
            @form={{form}}
          />
        {{/let}}
      </form.Section>

      {{#if @controller.showDeleteReason}}
        <form.Alert @type="warning" class="edit-category-delete-warning">
          {{htmlSafe @controller.model.cannot_delete_reason}}
        </form.Alert>
      {{/if}}

      <form.Actions class="edit-category-footer">
        <form.Submit
          @disabled={{not (@controller.canSaveForm transientData)}}
          @label={{@controller.saveLabel}}
          id="save-category"
        />

        {{#if @controller.model.can_delete}}
          <form.Button
            @disabled={{@controller.deleteDisabled}}
            @action={{@controller.deleteCategory}}
            @icon="trash-can"
            @label="category.delete"
            class="btn-danger"
          />
        {{else if @controller.model.id}}
          <form.Button
            @disabled={{@controller.deleteDisabled}}
            @action={{@controller.toggleDeleteTooltip}}
            @icon="circle-question"
            @label="category.delete"
            class="btn-default"
          />
        {{/if}}
      </form.Actions>
    </Form>
  </div>
</template>
