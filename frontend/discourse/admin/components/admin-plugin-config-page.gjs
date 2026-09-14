import Component from "@glimmer/component";
import { service } from "@ember/service";
import { headerActionComponentForPlugin } from "discourse/lib/admin-plugin-header-actions";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DNavItem from "discourse/ui-kit/d-nav-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";
import AdminPluginConfigArea from "./admin-plugin-config-area";

export default class AdminPluginConfigPage extends Component {
  @service adminPluginNavManager;

  get actionsOutletName() {
    return `admin-plugin-config-page-actions-${this.args.plugin.dasherizedName}`;
  }

  get headerActionComponent() {
    return headerActionComponentForPlugin(this.args.plugin.dasherizedName);
  }

  get hideTabs() {
    return this.adminPluginNavManager.currentConfigNav.links.length <= 1;
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
        @descriptionLabel={{@plugin.about}}
        @headerActionComponent={{this.headerActionComponent}}
        @hideTabs={{this.hideTabs}}
        @learnMoreUrl={{@plugin.linkUrl}}
        @titleLabel={{@plugin.nameTitleized}}
      >
        <:breadcrumbs>
          <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
          <DBreadcrumbsItem
            @label={{i18n "admin.plugins.title"}}
            @path="/admin/plugins"
          />
          <DBreadcrumbsItem
            @label={{@plugin.nameTitleized}}
            @path="/admin/plugins/{{@plugin.name}}"
          />
        </:breadcrumbs>
        <:tabs>
          {{#each
            this.adminPluginNavManager.currentConfigNav.links
            as |navLink|
          }}
            <DNavItem
              class="admin-plugin-config-page__top-nav-item"
              title={{this.linkText navLink}}
              @currentWhen={{navLink.currentWhen}}
              @i18nLabel={{this.linkText navLink}}
              @route={{navLink.route}}
            >
              {{this.linkText navLink}}
            </DNavItem>
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
