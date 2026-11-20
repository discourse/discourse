import Component from "@glimmer/component";
import { service } from "@ember/service";
import ApiSections from "./api-sections.gjs";

/**
 * Renders a sidebar panel's sections as a page, for a section whose
 * navigation lives on its top-level page rather than in a menu.
 */
export default class SidebarPanelPage extends Component {
  @service sidebarState;

  get panel() {
    return this.sidebarState.panels.find(
      (panel) => panel.key === this.args.panelKey
    );
  }

  <template>
    {{#if this.panel}}
      <div class="sidebar-panel-page sidebar-sections {{@panelKey}}-panel">
        <ApiSections
          @collapsable={{true}}
          @expandActiveSection={{this.panel.expandActiveSection}}
          @panel={{this.panel}}
        />
      </div>
    {{/if}}
  </template>
}
