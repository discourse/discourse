import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="admin-emoji admin-config-page">
      <DPageHeader
        @titleLabel={{i18n "admin.config.emoji.title"}}
        @descriptionLabel={{i18n "admin.config.emoji.header_description"}}
        @hideTabs={{@controller.hideTabs}}
      >
        <:breadcrumbs>
          <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
          <DBreadcrumbsItem
            @path="/admin/config/emoji"
            @label={{i18n "admin.config.emoji.title"}}
          />
        </:breadcrumbs>
        <:actions as |actions|>
          <actions.Primary @route="adminEmojis.new" @label="admin.emoji.add" />
        </:actions>
        <:tabs>
          <NavItem
            @route="adminEmojis.settings"
            @label="settings"
            class="admin-emoji-tabs__settings"
          />
          <NavItem
            @route="adminEmojis.index"
            @label="admin.emoji.title"
            class="admin-emoji-tabs__emoji"
          />
        </:tabs>
      </DPageHeader>

      <div class="admin-container admin-config-page__main-area">
        {{outlet}}
      </div>
    </div>
  </template>
);
