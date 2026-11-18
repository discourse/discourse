import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import PageShellPanelSeparator from "discourse/components/page-shell/panel-separator";
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
      inert={{if this.pageShell.closingPanels.navigation true}}
      role={{if this.pageShell.enabled "complementary"}}
    >
      {{#if
        (or @showSidebar (eq this.pageShell.closingPanels.navigation "open"))
      }}
        <Sidebar @toggleSidebar={{@toggleSidebar}} />
        {{#if (and this.pageShell.enabled @showSidebar)}}
          <PageShellPanelSeparator @panel="navigation" />
        {{/if}}
      {{else if
        (and
          this.pageShell.enabled
          (or
            (eq this.pageShell.navigation "rail")
            (eq this.pageShell.closingPanels.navigation "rail")
          )
        )
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
