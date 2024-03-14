import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import i18n from "discourse-common/helpers/i18n";
import AdminPluginConfigArea from "./admin-plugin-config-area";

export default class extends Component {
  @service currentUser;

  get configNavRoutes() {
    return this.args.plugin.configNavRoutes || [];
  }

  get mainAreaClasses() {
    let classes = ["admin-plugin-config-page__main-area"];

    if (this.configNavRoutes.length) {
      classes.push("-with-inner-sidebar");
    } else {
      classes.push("-without-inner-sidebar");
    }

    return classes.join(" ");
  }

  <template>
    <div class="admin-plugin-config-page">
      <div class="admin-plugin-config-page__metadata">
        <h2>
          {{@plugin.nameTitleized}}
        </h2>
        <p>
          {{@plugin.about}}
          {{#if @plugin.linkUrl}}
            |
            <a
              href={{@plugin.linkUrl}}
              rel="noopener noreferrer"
              target="_blank"
            >
              {{i18n "admin.plugins.learn_more"}}
            </a>
          {{/if}}

        </p>
      </div>
      <div class="admin-plugin-config-page__content">
        <div class={{this.mainAreaClasses}}>
          <AdminPluginConfigArea
            @innerSidebarNavLinks={{@plugin.configNavRoutes}}
          >
            {{yield}}
          </AdminPluginConfigArea>
        </div>
      </div>
    </div>
  </template>
}
