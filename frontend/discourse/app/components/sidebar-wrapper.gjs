import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import Sidebar from "discourse/components/sidebar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class SidebarWrapper extends Component {
  @service pageShell;

  <template>
    <div
      aria-label={{if this.pageShell.enabled (i18n "page_shell.navigation")}}
      class={{dConcatClass
        "sidebar-wrapper"
        (if this.pageShell.enabled "page-shell__navigation")
      }}
      role={{if this.pageShell.enabled "complementary"}}
    >
      {{#if @showSidebar}}
        <Sidebar @toggleSidebar={{@toggleSidebar}} />
      {{else if
        (and this.pageShell.enabled (eq this.pageShell.navigation "rail"))
      }}
        <button
          class="btn btn-flat"
          title={{i18n "page_shell.expand_navigation"}}
          type="button"
          {{on "click" this.pageShell.openNavigation}}
        >
          {{i18n "page_shell.expand"}}
        </button>
      {{/if}}
    </div>
  </template>
}
