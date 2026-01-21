import { concat } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import EditCategoryGeneral from "discourse/admin/components/edit-category-general";
import EditCategoryGeneralV2 from "discourse/admin/components/edit-category-general-v2";
import EditCategoryImages from "discourse/admin/components/edit-category-images";
import EditCategoryImagesV2 from "discourse/admin/components/edit-category-images-v2";
import EditCategoryLocalizations from "discourse/admin/components/edit-category-localizations";
import EditCategorySecurity from "discourse/admin/components/edit-category-security";
import EditCategorySecurityV2 from "discourse/admin/components/edit-category-security-v2";
import EditCategorySettings from "discourse/admin/components/edit-category-settings";
import EditCategorySettingsV2 from "discourse/admin/components/edit-category-settings-v2";
import EditCategoryTags from "discourse/admin/components/edit-category-tags";
import EditCategoryTagsV2 from "discourse/admin/components/edit-category-tags-v2";
import EditCategoryTopicTemplate from "discourse/admin/components/edit-category-topic-template";
import EditCategoryTabsHorizontal from "discourse/admin/templates/edit-category/tabs-horizontal";
import EditCategoryTabsVertical from "discourse/admin/templates/edit-category/tabs-vertical";
import Form from "discourse/components/form";
import { not } from "discourse/truth-helpers";

const TAB_COMPONENTS = {
  general: EditCategoryGeneral,
  security: EditCategorySecurity,
  settings: EditCategorySettings,
  images: EditCategoryImages,
  "topic-template": EditCategoryTopicTemplate,
  tags: EditCategoryTags,
  localizations: EditCategoryLocalizations,
};

const TAB_COMPONENTS_V2 = {
  general: EditCategoryGeneralV2,
  security: EditCategorySecurityV2,
  settings: EditCategorySettingsV2,
  images: EditCategoryImagesV2,
  "topic-template": EditCategoryTopicTemplate,
  tags: EditCategoryTagsV2,
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
