import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default class extends Component {
  @service site;

  <template>
    <DPageHeader
      @descriptionLabel={{i18n "admin.config.login.header_description"}}
      @titleLabel={{i18n "admin.config.login.title"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
        <DBreadcrumbsItem
          @label={{i18n "admin.config.login.title"}}
          @path="/admin/config/login-and-authentication"
        />
      </:breadcrumbs>
      <:tabs>
        <DNavItem
          @label="admin.config.login.sub_pages.common_settings.title"
          @route="adminConfig.login.settings"
        />
        <DNavItem
          @label="admin.config.login.sub_pages.discourse_id.title"
          @route="adminConfig.login.discourse-id"
        />
        <DNavItem
          @label="admin.config.login.sub_pages.authenticators.title"
          @route="adminConfig.login.authenticators"
        />
        <DNavItem
          @label="admin.config.login.sub_pages.discourseconnect.title"
          @route="adminConfig.login.discourseconnect"
        />
        {{#each this.site.admin_config_login_routes as |login_route|}}
          <DNavItem
            @label={{concat "admin.config.login.sub_pages." login_route}}
            @route="adminConfig.login.plugin-tab"
            @routeParam={{login_route}}
          />
        {{/each}}
      </:tabs>
    </DPageHeader>

    <div class="admin-config-page__main-area">
      {{outlet}}
    </div>
  </template>
}
