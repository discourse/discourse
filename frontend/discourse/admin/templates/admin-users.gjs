import routeAction from "discourse/helpers/route-action";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
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
        <DNavItem
          @route="adminUsers.settings"
          @label="settings"
          class="admin-users-tabs__settings"
        />
        <DNavItem
          @route="adminUsersList.show"
          @routeParam="active"
          @label="admin.users.nav.active"
          class="admin-users-tabs__active"
        />
        <DNavItem
          @route="adminUsersList.show"
          @routeParam="new"
          @label="admin.users.nav.new"
          class="admin-users-tabs__new"
        />
        <DNavItem
          @route="adminUsersList.show"
          @routeParam="staff"
          @label="admin.users.nav.staff"
          class="admin-users-tabs__staff"
        />
        <DNavItem
          @route="adminUsersList.show"
          @routeParam="suspended"
          @label="admin.users.nav.suspended"
          class="admin-users-tabs__suspended"
        />
        <DNavItem
          @route="adminUsersList.show"
          @routeParam="silenced"
          @label="admin.users.nav.silenced"
          class="admin-users-tabs__silenced"
        />
        <DNavItem
          @route="adminUsersList.show"
          @routeParam="staged"
          @label="admin.users.nav.staged"
          class="admin-users-tabs__staged"
        />
        <DNavItem
          @route="adminGroups.index"
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
