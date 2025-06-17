import { fn } from "@ember/helper";
import { getOwner } from "@ember/owner";
import RouteTemplate from "ember-route-template";
import { and, not } from "truth-helpers";
import BreadCrumbs from "discourse/components/bread-crumbs";
import DButton from "discourse/components/d-button";
import EditCategoryTab from "discourse/components/edit-category-tab";
import Form from "discourse/components/form";
import htmlSafe from "discourse/helpers/html-safe";

function lookupComponent(context, name) {
  return getOwner(context).resolveRegistration(`component:${name}`);
}

export default RouteTemplate(
  <template>
    <div class="edit-category {{if @controller.expandedMenu 'expanded-menu'}}">
      <div class="edit-category-title-bar">
        <div class="edit-category-title">
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
        {{#if (and @controller.site.desktopView @controller.model.id)}}
          <DButton
            @action={{@controller.goBack}}
            @label="category.back"
            @icon="caret-left"
            class="category-back"
          />
        {{/if}}
      </div>

      <div class="edit-category-nav">
        <ul class="nav nav-stacked">
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
        </ul>
      </div>

      <Form
        @data={{@controller.formData}}
        @onDirtyCheck={{@controller.isLeavingForm}}
        as |form transientData|
      >
        <form.Section
          @title={{@controller.selectedTabTitle}}
          class="edit-category-content"
        >
          {{#each @controller.panels as |tabName|}}
            {{#let (lookupComponent @controller tabName) as |Tab|}}
              <Tab
                @selectedTab={{@controller.selectedTab}}
                @category={{@controller.model}}
                @action={{@controller.registerValidator}}
                @transientData={{transientData}}
                @form={{form}}
              />
            {{/let}}
          {{/each}}
        </form.Section>

        {{#if @controller.showDeleteReason}}
          <form.Alert @type="warning" class="edit-category-delete-warning">
            {{htmlSafe @controller.model.cannot_delete_reason}}
          </form.Alert>
        {{/if}}

        <form.Actions class="edit-category-footer">
          <form.Button
            @disabled={{not (@controller.canSaveForm transientData)}}
            @action={{fn @controller.saveCategory transientData}}
            @label={{@controller.saveLabel}}
            id="save-category"
            class="btn-primary"
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
);
