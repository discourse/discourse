import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { schedule } from "@ember/runloop";
import { PANEL_WRAPPER_ID } from "discourse/widgets/header";
import PanelPortal from "./header/panel-portal";

export default class LegacyHeaderIconShim extends Component {
  @tracked panelElement;

  constructor() {
    super(...arguments);
    schedule("afterRender", () => {
      this.panelElement = document.querySelector(`#${PANEL_WRAPPER_ID}`);
    });
  }

  <template>
    {{#let
      (component PanelPortal panelElement=this.panelElement)
      as |panelPortal|
    }}
      <@component @panelPortal={{panelPortal}} />
    {{/let}}
  </template>
}
