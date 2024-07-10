import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import DHeadlessTooltip from "float-kit/components/d-headless-tooltip";

export default class DTooltips extends Component {
  @service tooltip;

  <template>
    <div id="d-tooltip-portals"></div>

    {{#each this.tooltip.registeredTooltips key="id" as |tooltip|}}
      {{#if tooltip.detachedTrigger}}
        <DHeadlessTooltip @tooltip={{tooltip}} />
      {{/if}}
    {{/each}}
  </template>
}
