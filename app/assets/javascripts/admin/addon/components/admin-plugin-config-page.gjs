import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
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
      {{#if this.adminPluginNavManager.isTopMode}}
        <AdminPluginConfigTopNav />
      {{/if}}

      <DBreadcrumbsContainer />

      <DBreadcrumbsItem as |linkClass|>
        <LinkTo @route="admin" class={{linkClass}}>
          {{i18n "admin_title"}}
        </LinkTo>
      </DBreadcrumbsItem>

      <DBreadcrumbsItem as |linkClass|>
        <LinkTo @route="adminPlugins" class={{linkClass}}>
          {{i18n "admin.plugins.title"}}
        </LinkTo>
      </DBreadcrumbsItem>

      <DBreadcrumbsItem as |linkClass|>
        <LinkTo
          @route="adminPlugins.show"
          @model={{@plugin}}
          class={{linkClass}}
        >
          {{@plugin.nameTitleized}}
        </LinkTo>
      </DBreadcrumbsItem>

      <AdminPluginConfigMetadata @plugin={{@plugin}} />

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
