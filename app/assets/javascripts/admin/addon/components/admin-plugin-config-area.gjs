import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";

export default class AdminPluginConfigArea extends Component {
  @service adminPluginNavManager;

  linkText(navLink) {
    if (navLink.label) {
      return i18n(navLink.label);
    } else {
      return navLink.text;
    }
  }

  <template>
    {{#if this.adminPluginNavManager.isSidebarMode}}
      <nav class="admin-nav admin-plugin-inner-sidebar-nav pull-left">
        <ul class="nav nav-stacked">
          {{#each
            this.adminPluginNavManager.currentConfigNav.links
            as |navLink|
          }}
            <li
              class={{concatClass
                "admin-plugin-inner-sidebar-nav__item"
                navLink.route
              }}
            >
              <LinkTo
                @route={{navLink.route}}
                @model={{navLink.model}}
                title={{this.linkText navLink}}
              >
                {{this.linkText navLink}}
              </LinkTo>
            </li>
          {{/each}}
        </ul>
      </nav>
    {{/if}}
    <section class="admin-plugin-config-area">
      {{yield}}
    </section>
  </template>
}
