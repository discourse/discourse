import Component from "@glimmer/component";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import DHeadlessTooltip from "discourse/float-kit/components/d-headless-tooltip";

export default class DTooltips extends Component {
  @service sheetLayerStore;
  @service tooltip;

  <template>
    <div
      id="d-tooltip-portals"
      {{didInsert this.sheetLayerStore.registerAutomaticLayerElement}}
      {{willDestroy this.sheetLayerStore.unregisterAutomaticLayerElement}}
    ></div>

    {{#each this.tooltip.registeredTooltips key="id" as |tooltip|}}
      {{#if tooltip.detachedTrigger}}
        <DHeadlessTooltip @tooltip={{tooltip}} />
      {{/if}}
    {{/each}}
  </template>
}
