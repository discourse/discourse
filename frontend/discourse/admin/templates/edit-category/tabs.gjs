import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import ChangesBanner from "discourse/admin/components/changes-banner";
import EditCategoryLocalizations from "discourse/admin/components/edit-category-localizations";
import EditCategoryTopicTemplate from "discourse/admin/components/edit-category-topic-template";
import UpsertCategoryAppearance from "discourse/admin/components/upsert-category/appearance";
import UpsertCategoryGeneral from "discourse/admin/components/upsert-category/general";
import UpsertCategoryModeration from "discourse/admin/components/upsert-category/moderation";
import UpsertCategorySecurity from "discourse/admin/components/upsert-category/security";
import UpsertCategorySettings from "discourse/admin/components/upsert-category/settings";
import UpsertCategoryTags from "discourse/admin/components/upsert-category/tags";
import EditCategoryTabsHorizontal from "discourse/admin/templates/edit-category/tabs-horizontal";
import EditCategoryTypeSchemaFields from "discourse/components/edit-category-type-schema-fields";
import Form from "discourse/components/form";
import { bind } from "discourse/lib/decorators";
import { registeredEditCategoryTabs } from "discourse/lib/edit-category-tabs";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const TAB_COMPONENTS = {
  general: UpsertCategoryGeneral,
  security: UpsertCategorySecurity,
  settings: UpsertCategorySettings,
  moderation: UpsertCategoryModeration,
  images: UpsertCategoryAppearance,
  "topic-template": EditCategoryTopicTemplate,
  tags: UpsertCategoryTags,
  localizations: EditCategoryLocalizations,
};

const UnknownCategoryType = <template>
  <div class="edit-category-unknown-category-type">
    <h3>{{i18n "category.unknown_category_type"}}</h3>
    <p>{{i18n
        "category.unknown_category_type_description"
        categoryType=@categoryType
      }}</p>
  </div>
</template>;

export default class Tabs extends Component {
  @bind
  componentFor(name) {
    name = name.replace("edit-category-", "");

    if (TAB_COMPONENTS[name]) {
      return TAB_COMPONENTS[name];
    }

    // Shows additional tabs manually registered by plugins
    const pluginTab = registeredEditCategoryTabs.find((tab) => tab.id === name);
    if (pluginTab) {
      return pluginTab.component;
    }

    // Used to show category type specific tabs. Types may be registered by plugins.
    if (this.args.controller.model.categoryTypes?.[name]) {
      return EditCategoryTypeSchemaFields;
    }

    return UnknownCategoryType;
  }

  <template>
    <div class="edit-category {{if @controller.expandedMenu 'expanded-menu'}}">
      <EditCategoryTabsHorizontal
        @controller={{@controller}}
        class="edit-category-page-header"
      />

      <Form
        @data={{@controller.formData}}
        @onDirtyCheck={{@controller.isLeavingForm}}
        @onSubmit={{@controller.saveCategory}}
        @validate={{@controller.validateForm}}
        @onRegisterApi={{@controller.onRegisterFormApi}}
        @onReset={{@controller.onFormReset}}
        as |form transientData|
      >
        <form.Section
          class="edit-category-content edit-category-tab-{{@controller.selectedTab}}"
        >
          {{#let
            (this.componentFor
              (concat "edit-category-" @controller.selectedTab)
            )
            as |Tab|
          }}
            <Tab
              @selectedTab={{@controller.selectedTab}}
              @categoryType={{@controller.selectedTab}}
              @category={{@controller.model}}
              @registerValidator={{@controller.registerValidator}}
              @registerAfterReset={{@controller.registerAfterReset}}
              @transientData={{transientData}}
              @form={{form}}
              @setSelectedTab={{@controller.setSelectedTab}}
            />
          {{/let}}
        </form.Section>

        {{#if @controller.showDeleteReason}}
          <form.Alert @type="warning" class="edit-category-delete-warning">
            {{trustHTML @controller.model.cannot_delete_reason}}
          </form.Alert>
        {{/if}}

        {{#if (or @controller.model.can_delete @controller.model.id)}}
          <form.Actions class="edit-category-footer">
            {{#if @controller.model.can_delete}}
              <form.Button
                @action={{@controller.deleteCategory}}
                @icon="trash-can"
                @label="category.delete"
                class="btn-danger btn-small"
              />
            {{else}}
              <form.Button
                @action={{@controller.toggleDeleteTooltip}}
                @icon="circle-question"
                @label="category.delete"
                class="btn-default btn-small"
              />
            {{/if}}
          </form.Actions>
        {{/if}}
      </Form>

      {{#if (or @controller.model.isNew @controller.isFormDirty)}}
        <ChangesBanner
          @bannerLabel={{i18n "category.unsaved_changes"}}
          @saveLabel={{if
            @controller.model.id
            (i18n "category.save")
            (i18n "category.create_category")
          }}
          @discardLabel={{i18n "form_kit.reset"}}
          @save={{@controller.formApi.submit}}
          @discard={{@controller.formApi.reset}}
        />
      {{/if}}
    </div>
  </template>
}
