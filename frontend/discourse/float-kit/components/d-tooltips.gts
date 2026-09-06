import Component from "@glimmer/component";
import { service } from "@ember/service";
import DHeadlessTooltip from "discourse/float-kit/components/d-headless-tooltip";
import type TooltipService from "discourse/float-kit/services/tooltip";

/**
 * The app-root host for service-driven tooltips, mounted once. It provides the
 * portal outlet that tooltips teleport their content into, and renders a
 * `DHeadlessTooltip` for every tooltip registered with the `tooltip` service
 * whose trigger is detached (i.e. created through the service rather than by
 * `DTooltip`).
 */
export default class DTooltips extends Component {
  @service declare tooltip: TooltipService;

  <template>
    <div id="d-tooltip-portals"></div>

    {{#each this.tooltip.registeredTooltips key="id" as |tooltip|}}
      {{#if tooltip.detachedTrigger}}
        <DHeadlessTooltip @tooltip={{tooltip}} />
      {{/if}}
    {{/each}}
  </template>
}
