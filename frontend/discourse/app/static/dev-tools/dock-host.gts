import Component from "@glimmer/component";
import {
  activateDockTool,
  closeDock,
  dockPanels,
  dockState,
} from "discourse/static/dev-tools/dock";
import DPanelDock from "discourse/ui-kit/panel-dock";

export default class DevToolsDockHost extends Component {
  get panels() {
    return dockPanels();
  }

  get state() {
    return dockState();
  }

  get tabs() {
    return this.panels.map(({ toolId, label, component }) => ({
      id: toolId,
      label,
      component,
    }));
  }

  get shouldRender() {
    return this.state.open && this.panels.length > 0;
  }

  <template>
    {{#if this.shouldRender}}
      <DPanelDock
        @context="dev-tools"
        @isOpen={{this.state.open}}
        @dockable={{true}}
        @defaultSide="bottom"
        @tabs={{this.tabs}}
        @activeTab={{this.state.activeTool}}
        @onActivateTab={{activateDockTool}}
        @onClose={{closeDock}}
      />
    {{/if}}
  </template>
}
