import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import { i18n } from "discourse-i18n";

export default class extends Component {
  @service site;

  <template>
    <DPageHeader
      @titleLabel={{i18n "admin.config.login.title"}}
      @descriptionLabel={{i18n "admin.config.login.header_description"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/config/login-and-authentication"
          @label={{i18n "admin.config.login.title"}}
        />
      </:breadcrumbs>
      <:tabs>
        <NavItem
          @route="adminConfig.login.settings"
          @label="admin.config.login.sub_pages.common_settings.title"
        />
        <NavItem
          @route="adminConfig.login.authenticators"
          @label="admin.config.login.sub_pages.authenticators.title"
        />
        <NavItem
          @route="adminConfig.login.discourseconnect"
          @label="admin.config.login.sub_pages.discourseconnect.title"
        />
        {{#each this.site.admin_config_login_routes as |login_route|}}
          <NavItem
            @route="adminConfig.login.plugin-tab"
            @routeParam={{login_route}}
            @label={{concat "admin.config.login.sub_pages." login_route}}
          />
        {{/each}}
      </:tabs>
    </DPageHeader>

    <div class="admin-config-page__main-area">
      {{outlet}}
    </div>
  </template>
}
