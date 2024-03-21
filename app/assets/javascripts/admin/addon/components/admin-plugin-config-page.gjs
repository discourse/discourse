import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import NavItem from "discourse/components/nav-item";
import i18n from "discourse-common/helpers/i18n";
import AdminPluginConfigArea from "./admin-plugin-config-area";

export default class extends Component {
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
      {{#if this.adminPluginNavManager.isTopMode}}
        <div class="admin-controls">
          <HorizontalOverflowNav
            class="nav-pills action-list main-nav nav plugin-nav"
          >
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
          </HorizontalOverflowNav>
        </div>
      {{/if}}

      <div class="admin-plugin-config-page__metadata">
        <div class="admin-plugin-config-area__metadata-title">
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
      </div>
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
