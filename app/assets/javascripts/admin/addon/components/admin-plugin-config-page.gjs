import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import NavItem from "discourse/components/nav-item";
import PluginOutlet from "discourse/components/plugin-outlet";
import i18n from "discourse-common/helpers/i18n";
import AdminPageHeader from "./admin-page-header";
import AdminPluginConfigArea from "./admin-plugin-config-area";

export default class AdminPluginConfigPage extends Component {
  @service currentUser;
  @service adminPluginNavManager;

  get mainAreaClasses() {
    let classes = ["admin-plugin-config-page__main-area"];

    if (this.adminPluginNavManager.isSidebarMode) {
      classes.push("-with-inner-sidebar");
    } else {
      classes.push("-without-inner-sidebar");
    }

    return classes.join(" ");
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
      <AdminPageHeader
        @titleLabelTranslated={{@plugin.nameTitleized}}
        @descriptionLabelTranslated={{@plugin.about}}
        @learnMoreUrl={{@plugin.linkUrl}}
      >
        <:breadcrumbs>

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
          {{#if this.adminPluginNavManager.isTopMode}}
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
          {{/if}}
        </:tabs>
        <:actions as |actions|>
          <PluginOutlet
            @name="admin-plugin-config-page-actions"
            @outletArgs={{hash plugin=@plugin actions=actions}}
          />
        </:actions>
      </AdminPageHeader>

      <div class="admin-plugin-config-page__content">
        <div class={{this.mainAreaClasses}}>
          <AdminPluginConfigArea>
            {{yield}}
          </AdminPluginConfigArea>
        </div>
      </div>
    </div>
  </template>
}
