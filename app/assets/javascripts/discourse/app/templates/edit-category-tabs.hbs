<div class="edit-category {{if this.expandedMenu 'expanded-menu'}}">
  <div class="edit-category-title-bar">
    <div class="edit-category-title">
      <h2>{{this.title}}</h2>
      {{#if this.model.id}}
        <BreadCrumbs
          @categories={{this.breadcrumbCategories}}
          @category={{this.model}}
          @noSubcategories={{this.model.noSubcategories}}
          @editingCategory={{true}}
          @editingCategoryTab={{this.selectedTab}}
        />
      {{/if}}
    </div>
    {{#if (and this.site.desktopView this.model.id)}}
      <DButton
        @action={{action "goBack"}}
        @label="category.back"
        @icon="caret-left"
        class="category-back"
      />
    {{/if}}
  </div>

  <div class="edit-category-nav">
    <ul class="nav nav-stacked">
      <EditCategoryTab
        @panels={{this.panels}}
        @selectedTab={{this.selectedTab}}
        @params={{this.parentParams}}
        @tab="general"
      />
      <EditCategoryTab
        @panels={{this.panels}}
        @selectedTab={{this.selectedTab}}
        @params={{this.parentParams}}
        @tab="security"
      />
      <EditCategoryTab
        @panels={{this.panels}}
        @selectedTab={{this.selectedTab}}
        @params={{this.parentParams}}
        @tab="settings"
      />
      <EditCategoryTab
        @panels={{this.panels}}
        @selectedTab={{this.selectedTab}}
        @params={{this.parentParams}}
        @tab="images"
      />
      <EditCategoryTab
        @panels={{this.panels}}
        @selectedTab={{this.selectedTab}}
        @params={{this.parentParams}}
        @tab="topic-template"
      />
      {{#if this.siteSettings.tagging_enabled}}
        <EditCategoryTab
          @panels={{this.panels}}
          @selectedTab={{this.selectedTab}}
          @params={{this.parentParams}}
          @tab="tags"
        />
      {{/if}}

      {{#if this.siteSettings.experimental_content_localization}}
        <EditCategoryTab
          @panels={{this.panels}}
          @selectedTab={{this.selectedTab}}
          @params={{this.parentParams}}
          @tab="localizations"
        />
      {{/if}}
    </ul>
  </div>

  <Form
    @data={{this.formData}}
    @onDirtyCheck={{this.isLeavingForm}}
    as |form transientData|
  >
    <form.Section
      @title={{this.selectedTabTitle}}
      class="edit-category-content"
    >
      {{#each this.panels as |tab|}}
        {{component
          tab
          selectedTab=this.selectedTab
          category=this.model
          action=this.registerValidator
          transientData=transientData
          form=form
        }}
      {{/each}}
    </form.Section>

    {{#if this.showDeleteReason}}
      <form.Alert @type="warning" class="edit-category-delete-warning">
        {{html-safe this.model.cannot_delete_reason}}
      </form.Alert>
    {{/if}}

    <form.Actions class="edit-category-footer">
      <form.Button
        @disabled={{not (this.canSaveForm transientData)}}
        @action={{fn this.saveCategory transientData}}
        @label={{this.saveLabel}}
        id="save-category"
        class="btn-primary"
      />

      {{#if this.model.can_delete}}
        <form.Button
          @disabled={{this.deleteDisabled}}
          @action={{this.deleteCategory}}
          @icon="trash-can"
          @label="category.delete"
          class="btn-danger"
        />
      {{else if this.model.id}}
        <form.Button
          @disabled={{this.deleteDisabled}}
          @action={{this.toggleDeleteTooltip}}
          @icon="circle-question"
          @label="category.delete"
          class="btn-default"
        />
      {{/if}}
    </form.Actions>
  </Form>
</div>