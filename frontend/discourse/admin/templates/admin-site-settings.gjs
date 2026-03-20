import { LinkTo } from "@ember/routing";
import AdminSiteSettingsChangesBanner from "discourse/admin/components/admin-site-settings-changes-banner";
import AdminSiteSettingsFilterControls from "discourse/admin/components/admin-site-settings-filter-controls";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default <template>
  <DPageHeader
    @titleLabel={{i18n "admin.config.site_settings.title"}}
    @descriptionLabel={{i18n "admin.config.site_settings.header_description"}}
    @hideTabs={{true}}
  >
    <:breadcrumbs>
      <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @path="/admin/site_settings"
        @label={{i18n "admin.config.site_settings.title"}}
      />
    </:breadcrumbs>
  </DPageHeader>

  <AdminSiteSettingsFilterControls
    @initialFilter={{@controller.filter}}
    @onChangeFilter={{@controller.filterChanged}}
    @showMenu={{true}}
    @onToggleMenu={{@controller.toggleMenu}}
  />

  <div class="admin-nav admin-site-settings-category-nav pull-left">
    <ul class="nav nav-stacked">
      {{#each @controller.visibleSiteSettings as |category|}}
        <li
          class={{dConcatClass
            "admin-site-settings-category-nav__item"
            category.nameKey
          }}
        >
          <LinkTo
            @route="adminSiteSettingsCategory"
            @model={{category.nameKey}}
            class={{category.nameKey}}
            title={{category.name}}
          >
            {{category.name}}
            {{#if @controller.filtersApplied}}
              <span class="count">({{category.count}})</span>
            {{/if}}
          </LinkTo>
        </li>
      {{/each}}
    </ul>
  </div>

  <div class="admin-detail pull-left mobile-closed">
    {{outlet}}
  </div>

  <div class="clearfix"></div>

  <AdminSiteSettingsChangesBanner />
</template>
