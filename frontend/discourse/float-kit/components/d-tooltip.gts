import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import type { AutoUpdateOptions } from "@floating-ui/dom";
import { type ComponentLike } from "@glint/template";
import { modifier } from "ember-modifier";
import DFloatBody from "discourse/float-kit/components/d-float-body";
import {
  type FloatCallback,
  type FloatTriggers,
  type FloatUiPlacement,
  TOOLTIP,
  type TooltipOptions,
  type VisibilityOptimizer,
} from "discourse/float-kit/lib/constants";
import DTooltipInstance from "discourse/float-kit/lib/d-tooltip-instance";
import type TooltipService from "discourse/float-kit/services/tooltip";
import { and } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

/** The object yielded to each of the tooltip's blocks. */
export interface DTooltipComponentArgs<Data = unknown> {
  close: FloatCallback;
  data?: Data;
}

interface DTooltipSignature<Data = unknown> {
  Element: HTMLSpanElement;
  Args: {
    /* Explicitly-read arguments (not part of the options bag). */
    icon?: string;
    label?: string;

    /* Every key of `TOOLTIP.options` (see `constants.ts` — the source of truth). */
    animated?: boolean;
    arrow?: boolean;
    beforeTrigger?: FloatCallback;
    closeOnClickOutside?: boolean;
    closeOnEscape?: boolean;
    closeOnScroll?: boolean;
    component?: ComponentLike<{ Args: { data?: Data; close?: FloatCallback } }>;
    content?: string;
    identifier?: string;
    inline?: boolean | null;
    interactive?: boolean;
    listeners?: boolean;
    maxWidth?: number;
    data?: Data;
    offset?: number;
    triggers?: FloatTriggers;
    untriggers?: FloatTriggers;
    placement?: FloatUiPlacement;
    shiftBeforeVisibilityOptimizer?: boolean;
    visibilityOptimizer?: VisibilityOptimizer;
    fallbackPlacements?: readonly FloatUiPlacement[];
    autoUpdate?: boolean | AutoUpdateOptions;
    trapTab?: boolean;
    onClose?: FloatCallback;
    onShow?: FloatCallback;
    onRegisterApi?: (instance: DTooltipInstance) => void;
    portalOutletElement?: HTMLElement;
  };
  Blocks: {
    default: [DTooltipComponentArgs<Data>];
    trigger: [DTooltipComponentArgs<Data>];
    content: [DTooltipComponentArgs<Data>];
  };
}

export default class DTooltip<Data = unknown> extends Component<
  DTooltipSignature<Data>
> {
  @service declare tooltip: TooltipService;

  tooltipInstance = new DTooltipInstance(getOwner(this)!, {
    ...this.allowedProperties,
    autoUpdate: true,
    listeners: true,
  } as Partial<TooltipOptions>);

  registerTrigger = modifier((element: HTMLElement) => {
    this.tooltipInstance.trigger = element;
    this.options.onRegisterApi?.(this.tooltipInstance);

    return () => {
      this.tooltipInstance.destroy();
    };
  });

  get options(): TooltipOptions {
    return this.tooltipInstance?.options;
  }

  get componentArgs(): DTooltipComponentArgs<Data> {
    return {
      close: this.tooltip.close,
      data: this.options.data as Data,
    };
  }

  get allowedProperties() {
    const properties: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(TOOLTIP.options)) {
      properties[key] = (this.args as Record<string, unknown>)[key] ?? value;
    }
    return properties;
  }

  <template>
    <span
      {{this.registerTrigger this.allowedProperties}}
      class={{dConcatClass
        "fk-d-tooltip__trigger"
        (if this.tooltipInstance.expanded "-expanded")
      }}
      role="button"
      id={{this.tooltipInstance.id}}
      data-identifier={{this.options.identifier}}
      data-trigger
      aria-expanded={{if this.tooltipInstance.expanded "true" "false"}}
      ...attributes
    >
      <span class="fk-d-tooltip__trigger-container">
        {{~#if (has-block "trigger")~}}
          {{yield this.componentArgs to="trigger"}}
        {{~else~}}
          {{#if @icon}}
            <span class="fk-d-tooltip__icon">
              {{~dIcon @icon~}}
            </span>
          {{/if}}
          {{#if @label}}
            <span class="fk-d-tooltip__label">{{@label}}</span>
          {{/if}}
        {{~/if~}}
      </span></span>
    {{~#if this.tooltipInstance.expanded~}}
      <DFloatBody
        @instance={{this.tooltipInstance}}
        @trapTab={{and this.options.interactive this.options.trapTab}}
        @mainClass={{dConcatClass
          "fk-d-tooltip__content"
          (concat this.options.identifier "-content")
        }}
        @innerClass="fk-d-tooltip__inner-content"
        @role="tooltip"
        @inline={{this.options.inline}}
      >
        {{#if (has-block)}}
          {{yield this.componentArgs}}
        {{else if (has-block "content")}}
          {{yield this.componentArgs to="content"}}
        {{else if this.options.component}}
          <this.options.component
            @data={{this.options.data}}
            @close={{this.tooltipInstance.close}}
          />
        {{else if this.options.content}}
          {{this.options.content}}
        {{/if}}
      </DFloatBody>
    {{~/if~}}
  </template>
}
