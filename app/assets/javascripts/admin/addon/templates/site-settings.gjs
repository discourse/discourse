import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";
import AdminSiteSettingsChangesBanner from "admin/components/admin-site-settings-changes-banner";
import AdminSiteSettingsFilterControls from "admin/components/admin-site-settings-filter-controls";

export default RouteTemplate(
  <template>
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
            class={{concatClass
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
);
