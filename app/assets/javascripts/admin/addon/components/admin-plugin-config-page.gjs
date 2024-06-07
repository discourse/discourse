import Component from "@glimmer/component";
import { service } from "@ember/service";
import DBreadcrumbsContainer from "discourse/components/d-breadcrumbs-container";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import i18n from "discourse-common/helpers/i18n";
import AdminPluginConfigArea from "./admin-plugin-config-area";
import AdminPluginConfigMetadata from "./admin-plugin-config-metadata";
import AdminPluginConfigTopNav from "./admin-plugin-config-top-nav";

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

  <template>
    <div class="admin-plugin-config-page">
      <DBreadcrumbsContainer />

      <DBreadcrumbsItem @route="admin" @label={{i18n "admin_title"}} />
      <DBreadcrumbsItem
        @route="adminPlugins"
        @label={{i18n "admin.plugins.title"}}
      />
      <DBreadcrumbsItem
        @route="adminPlugins.show"
        @model={{@plugin}}
        @label={{@plugin.nameTitleized}}
      />

      <AdminPluginConfigMetadata @plugin={{@plugin}} />

      {{#if this.adminPluginNavManager.isTopMode}}
        <AdminPluginConfigTopNav />
      {{/if}}

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
