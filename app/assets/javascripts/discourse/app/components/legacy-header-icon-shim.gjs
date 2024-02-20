import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { schedule } from "@ember/runloop";
import { PANEL_WRAPPER_ID } from "discourse/widgets/header";
import PanelWrapper from "./glimmer-header/panel-wrapper";

export default class LegacyHeaderIconShim extends Component {
  @tracked panelElement;

  constructor() {
    super(...arguments);
    schedule("afterRender", () => {
      this.panelElement = document.querySelector(`#${PANEL_WRAPPER_ID}`);
    });
  }

  <template>
    {{#with
      (component PanelWrapper panelElement=this.panelElement)
      as |panelWrapper|
    }}
      <@component @panelWrapper={{panelWrapper}} />
    {{/with}}
  </template>
}
