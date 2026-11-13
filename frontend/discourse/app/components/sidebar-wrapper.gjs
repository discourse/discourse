import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import PageShellPrototypeRegion from "discourse/components/page-shell-prototype-region";
import Sidebar from "discourse/components/sidebar";
import { i18n } from "discourse-i18n";

export default class SidebarWrapper extends Component {
  @service pageShellPrototype;

  <template>
    <PageShellPrototypeRegion
      class="page-shell-prototype__navigation-slot"
      @enabled={{this.pageShellPrototype.enabled}}
    >
      <div class="sidebar-wrapper">
        {{#if @showSidebar}}
          <Sidebar @toggleSidebar={{@toggleSidebar}} />
        {{else if
          (and
            this.pageShellPrototype.enabled
            (eq this.pageShellPrototype.navigation "rail")
          )
        }}
          <button
            class="btn btn-flat"
            title={{i18n "page_shell_prototype.expand_navigation"}}
            type="button"
            {{on "click" this.pageShellPrototype.openNavigation}}
          >
            {{i18n "page_shell_prototype.expand"}}
          </button>
        {{/if}}
      </div>
    </PageShellPrototypeRegion>
  </template>
}
