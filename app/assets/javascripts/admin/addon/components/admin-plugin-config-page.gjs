import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
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
