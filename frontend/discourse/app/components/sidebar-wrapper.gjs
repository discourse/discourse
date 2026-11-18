import Component from "@glimmer/component";
import { service } from "@ember/service";
import PageShellPanelSeparator from "discourse/components/page-shell/panel-separator";
import Sidebar from "discourse/components/sidebar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class SidebarWrapper extends Component {
  @service pageShell;

  get rail() {
    return this.pageShell.enabled && this.pageShell.navigation === "rail";
  }

  <template>
    <div
      aria-label={{if this.pageShell.enabled (i18n "page_shell.navigation")}}
      class={{dConcatClass
        "sidebar-wrapper"
        (if this.pageShell.enabled "page-shell__navigation")
      }}
      role={{if this.pageShell.enabled "complementary"}}
    >
      {{#if (or @showSidebar this.rail)}}
        <Sidebar @rail={{this.rail}} @toggleSidebar={{@toggleSidebar}} />
        {{#if (and this.pageShell.enabled @showSidebar)}}
          <PageShellPanelSeparator @panel="navigation" />
        {{/if}}
      {{/if}}
    </div>
  </template>
}
