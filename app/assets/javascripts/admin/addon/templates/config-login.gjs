import Component from "@glimmer/component";
import { service } from "@ember/service";
import RouteTemplate from "ember-route-template";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  class extends Component {
    @service siteSettings;

    get samlPluginPresent() {
      return "saml_enabled" in this.siteSettings;
    }

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
          <NavItem
            @route="adminConfig.login.oauth2"
            @label="admin.config.login.sub_pages.oauth2.title"
          />
          <NavItem
            @route="adminConfig.login.oidc"
            @label="admin.config.login.sub_pages.oidc.title"
          />
          {{#if this.samlPluginPresent}}
            <NavItem
              @route="adminConfig.login.saml"
              @label="admin.config.login.sub_pages.saml.title"
            />
          {{/if}}
        </:tabs>
      </DPageHeader>

      <div class="admin-config-page__main-area">
        {{outlet}}
      </div>
    </template>
  }
);
