import Component from "@glimmer/component";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import NavItem from "discourse/components/nav-item";
import { headerActionComponentForPlugin } from "discourse/lib/admin-plugin-header-actions";
import { i18n } from "discourse-i18n";
import AdminPluginConfigArea from "./admin-plugin-config-area";

export default class AdminPluginConfigPage extends Component {
  @service currentUser;
  @service adminPluginNavManager;

  get actionsOutletName() {
    return `admin-plugin-config-page-actions-${this.args.plugin.dasherizedName}`;
  }

  get headerActionComponent() {
    return headerActionComponentForPlugin(this.args.plugin.dasherizedName);
  }

  linkText(navLink) {
    if (navLink.label) {
      return i18n(navLink.label);
    } else {
      return navLink.text;
    }
  }

  <template>
    <div class="admin-plugin-config-page">
      <DPageHeader
        @titleLabel={{@plugin.nameTitleized}}
        @descriptionLabel={{@plugin.about}}
        @learnMoreUrl={{@plugin.linkUrl}}
        @headerActionComponent={{this.headerActionComponent}}
      >
        <:breadcrumbs>
          <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
          <DBreadcrumbsItem
            @path="/admin/plugins"
            @label={{i18n "admin.plugins.title"}}
          />
          <DBreadcrumbsItem
            @path="/admin/plugins/{{@plugin.name}}"
            @label={{@plugin.nameTitleized}}
          />
        </:breadcrumbs>
        <:tabs>
          {{#each
            this.adminPluginNavManager.currentConfigNav.links
            as |navLink|
          }}
            <NavItem
              @route={{navLink.route}}
              @i18nLabel={{this.linkText navLink}}
              title={{this.linkText navLink}}
              class="admin-plugin-config-page__top-nav-item"
            >
              {{this.linkText navLink}}
            </NavItem>
          {{/each}}
        </:tabs>
      </DPageHeader>

      <div class="admin-plugin-config-page__content">
        <div class="admin-plugin-config-page__main-area -without-inner-sidebar">
          <AdminPluginConfigArea>
            {{yield}}
          </AdminPluginConfigArea>
        </div>
      </div>
    </div>
  </template>
}
