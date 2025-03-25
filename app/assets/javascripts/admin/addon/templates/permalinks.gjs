import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="admin-permalinks admin-config-page">
      <DPageHeader
        @titleLabel={{i18n "admin.config.permalinks.title"}}
        @descriptionLabel={{i18n "admin.config.permalinks.header_description"}}
        @learnMoreUrl="https://meta.discourse.org/t/20930"
      >
        <:breadcrumbs>
          <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
          <DBreadcrumbsItem
            @path="/admin/config/permalinks"
            @label={{i18n "admin.config.permalinks.title"}}
          />
        </:breadcrumbs>
        <:actions as |actions|>
          <actions.Primary
            @route="adminPermalinks.new"
            @title="admin.permalink.add"
            @label="admin.permalink.add"
            class="admin-permalinks__header-add-permalink"
          />
        </:actions>
        <:tabs>
          <NavItem
            @route="adminPermalinks.settings"
            @label="admin.permalink.nav.settings"
            class="admin-permalinks-tabs__settings"
          />
          <NavItem
            @route="adminPermalinks.index"
            @label="admin.permalink.nav.permalinks"
            class="admin-permalins-permalinks"
          />
        </:tabs>
      </DPageHeader>
      <div class="admin-container admin-config-page__main-area">
        {{outlet}}
      </div>
    </div>
  </template>
);
