import EditCategoryTab from "discourse/admin/components/edit-category-tab";
import BreadCrumbs from "discourse/components/bread-crumbs";
import DButton from "discourse/components/d-button";
import { and } from "discourse/truth-helpers";

const EditCategoryTabsVerticalTemplate = <template>
  <div class="edit-category-title-bar">
    <div class="edit-category-title">
      <h2 class="edit-category-title-text">
        <span
          class="edit-category-static-title"
        >{{@controller.baseTitle}}</span>
        <span class="edit-category-preview-badge">
          {{#if @controller.showPreviewBadge}}
            {{@controller.previewBadge}}
          {{/if}}
        </span>
      </h2>
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
        @icon="angle-left"
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
</template>;

export default EditCategoryTabsVerticalTemplate;
