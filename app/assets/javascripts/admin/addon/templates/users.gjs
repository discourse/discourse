import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <div class="admin-users admin-config-page">
      <DPageHeader
        @titleLabel={{i18n "admin.config.users.title"}}
        @descriptionLabel={{i18n "admin.config.users.header_description"}}
        @learnMoreUrl="https://meta.discourse.org/t/accessing-a-user-s-admin-page/311859"
      >
        <:breadcrumbs>
          <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
          <DBreadcrumbsItem
            @path="/admin/users/list"
            @label={{i18n "admin.config.users.title"}}
          />
        </:breadcrumbs>
        <:actions as |actions|>
          {{#if @controller.currentUser.can_invite_to_forum}}
            <actions.Primary
              @action={{routeAction "sendInvites"}}
              @title="admin.invite.button_title"
              @label="admin.invite.button_text"
              class="admin-users__header-send-invites"
            />
          {{/if}}

          {{#if @controller.currentUser.admin}}
            <actions.Primary
              @action={{routeAction "exportUsers"}}
              @title="admin.export_csv.button_title.user"
              @label="admin.export_csv.button_text"
              class="admin-users__header-export-users"
            />
          {{/if}}
        </:actions>
        <:tabs>
          <NavItem
            @route="adminUsers.settings"
            @label="settings"
            class="admin-users-tabs__settings"
          />
          <NavItem
            @route="adminUsersList.show"
            @routeParam="active"
            @label="admin.users.nav.active"
            class="admin-users-tabs__active"
          />
          <NavItem
            @route="adminUsersList.show"
            @routeParam="new"
            @label="admin.users.nav.new"
            class="admin-users-tabs__new"
          />
          <NavItem
            @route="adminUsersList.show"
            @routeParam="staff"
            @label="admin.users.nav.staff"
            class="admin-users-tabs__staff"
          />
          <NavItem
            @route="adminUsersList.show"
            @routeParam="suspended"
            @label="admin.users.nav.suspended"
            class="admin-users-tabs__suspended"
          />
          <NavItem
            @route="adminUsersList.show"
            @routeParam="silenced"
            @label="admin.users.nav.silenced"
            class="admin-users-tabs__silenced"
          />
          <NavItem
            @route="adminUsersList.show"
            @routeParam="staged"
            @label="admin.users.nav.staged"
            class="admin-users-tabs__staged"
          />
          <NavItem
            @route="groups"
            @label="groups.index.title"
            class="admin-users-tabs__groups"
          />
        </:tabs>
      </DPageHeader>
      <div class="admin-container admin-config-page__main-area">
      </div>
    </div>

    <div class="admin-container admin-config-page__main-area">
      {{outlet}}
    </div>
  </template>
);
