import { concat } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import EditCategoryGeneral from "discourse/admin/components/edit-category-general";
import EditCategoryImages from "discourse/admin/components/edit-category-images";
import EditCategoryLocalizations from "discourse/admin/components/edit-category-localizations";
import EditCategorySecurity from "discourse/admin/components/edit-category-security";
import EditCategorySettings from "discourse/admin/components/edit-category-settings";
import EditCategoryTags from "discourse/admin/components/edit-category-tags";
import EditCategoryTopicTemplate from "discourse/admin/components/edit-category-topic-template";
import UpsertCategoryAppearance from "discourse/admin/components/upsert-category/appearance";
import UpsertCategoryGeneral from "discourse/admin/components/upsert-category/general";
import UpsertCategorySecurity from "discourse/admin/components/upsert-category/security";
import UpsertCategorySettings from "discourse/admin/components/upsert-category/settings";
import UpsertCategoryTags from "discourse/admin/components/upsert-category/tags";
import EditCategoryTabsHorizontal from "discourse/admin/templates/edit-category/tabs-horizontal";
import EditCategoryTabsVertical from "discourse/admin/templates/edit-category/tabs-vertical";
import Form from "discourse/components/form";

const TAB_COMPONENTS = {
  general: EditCategoryGeneral,
  security: EditCategorySecurity,
  settings: EditCategorySettings,
  images: EditCategoryImages,
  "topic-template": EditCategoryTopicTemplate,
  tags: EditCategoryTags,
  localizations: EditCategoryLocalizations,
};

// Gated behind the enable_simplified_category_creation upcoming change
const TAB_COMPONENTS_V2 = {
  general: UpsertCategoryGeneral,
  security: UpsertCategorySecurity,
  settings: UpsertCategorySettings,
  images: UpsertCategoryAppearance,
  "topic-template": EditCategoryTopicTemplate,
  tags: UpsertCategoryTags,
  localizations: EditCategoryLocalizations,
};

function componentFor(name, useSimplified) {
  name = name.replace("edit-category-", "");
  const components = useSimplified ? TAB_COMPONENTS_V2 : TAB_COMPONENTS;

  if (!components[name]) {
    throw new Error(`No category-tab component found for tab name: ${name}`);
  }
  return components[name];
}

export default <template>
  <div class="edit-category {{if @controller.expandedMenu 'expanded-menu'}}">
    {{#if @controller.siteSettings.enable_simplified_category_creation}}
      <EditCategoryTabsHorizontal @controller={{@controller}} />
    {{else}}
      <EditCategoryTabsVertical @controller={{@controller}} />
    {{/if}}

    <Form
      @data={{@controller.formData}}
      @onDirtyCheck={{@controller.isLeavingForm}}
      @onSubmit={{@controller.saveCategory}}
      @validate={{@controller.validateForm}}
      as |form transientData|
    >
      <form.Section
        class="edit-category-content edit-category-tab-{{@controller.selectedTab}}"
      >
        {{#if @controller.siteSettings.enable_simplified_category_creation}}

          {{#let
            (componentFor
              (concat "edit-category-" @controller.selectedTab)
              @controller.siteSettings.enable_simplified_category_creation
            )
            as |Tab|
          }}
            <Tab
              @selectedTab={{@controller.selectedTab}}
              @category={{@controller.model}}
              @registerValidator={{@controller.registerValidator}}
              @transientData={{transientData}}
              @form={{form}}
              @updatePreview={{@controller.updatePreview}}
              @setSelectedTab={{@controller.setSelectedTab}}
            />
          {{/let}}
        {{else}}
          {{#each @controller.panels as |tabName|}}
            {{#let
              (componentFor
                tabName
                @controller.siteSettings.enable_simplified_category_creation
              )
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
          {{/each}}
        {{/if}}
      </form.Section>

      {{#if @controller.showDeleteReason}}
        <form.Alert @type="warning" class="edit-category-delete-warning">
          {{htmlSafe @controller.model.cannot_delete_reason}}
        </form.Alert>
      {{/if}}

      <form.Actions class="edit-category-footer">
        <form.Submit @label={{@controller.saveLabel}} id="save-category" />

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
