import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import concatClass from "discourse/helpers/concat-class";
import I18n from "discourse-i18n";

export default class AdminPluginConfigArea extends Component {
  linkText(navLink) {
    if (navLink.label) {
      return I18n.t(navLink.label);
    } else {
      return navLink.text;
    }
  }

  <template>
    {{#if @innerSidebarNavLinks}}
      <nav class="admin-nav admin-plugin-inner-sidebar-nav pull-left">
        <ul class="nav nav-stacked">
          {{#each @innerSidebarNavLinks as |navLink|}}
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
