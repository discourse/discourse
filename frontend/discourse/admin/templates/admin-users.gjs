import routeAction from "discourse/helpers/route-action";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="admin-users admin-config-page">
    <DPageHeader
      @descriptionLabel={{i18n "admin.config.users.header_description"}}
      @learnMoreUrl="https://meta.discourse.org/t/accessing-a-user-s-admin-page/311859"
      @titleLabel={{i18n "admin.config.users.title"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
        <DBreadcrumbsItem
          @label={{i18n "admin.config.users.title"}}
          @path="/admin/users/list"
        />
      </:breadcrumbs>
      <:actions as |actions|>
        {{#if @controller.currentUser.can_invite_to_forum}}
          <actions.Primary
            class="admin-users__header-send-invites"
            @action={{routeAction "sendInvites"}}
            @label="admin.invite.button_text"
            @title="admin.invite.button_title"
          />
        {{/if}}

        {{#if @controller.currentUser.admin}}
          <actions.Primary
            class="admin-users__header-export-users"
            @action={{routeAction "exportUsers"}}
            @label="admin.export_csv.button_text"
            @title="admin.export_csv.button_title.user"
          />
        {{/if}}
      </:actions>
      <:tabs>
        <DNavItem
          class="admin-users-tabs__settings"
          @label="settings"
          @route="adminUsers.settings"
        />
        <DNavItem
          class="admin-users-tabs__active"
          @label="admin.users.nav.active"
          @route="adminUsersList.show"
          @routeParam="active"
        />
        <DNavItem
          class="admin-users-tabs__new"
          @label="admin.users.nav.new"
          @route="adminUsersList.show"
          @routeParam="new"
        />
        <DNavItem
          class="admin-users-tabs__staff"
          @label="admin.users.nav.staff"
          @route="adminUsersList.show"
          @routeParam="staff"
        />
        <DNavItem
          class="admin-users-tabs__suspended"
          @label="admin.users.nav.suspended"
          @route="adminUsersList.show"
          @routeParam="suspended"
        />
        <DNavItem
          class="admin-users-tabs__silenced"
          @label="admin.users.nav.silenced"
          @route="adminUsersList.show"
          @routeParam="silenced"
        />
        <DNavItem
          class="admin-users-tabs__staged"
          @label="admin.users.nav.staged"
          @route="adminUsersList.show"
          @routeParam="staged"
        />
        <DNavItem
          class="admin-users-tabs__groups"
          @label="groups.index.title"
          @route="adminGroups.index"
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
