import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { type ComponentLike } from "@glint/template";
import { modifier } from "ember-modifier";
import DFloatBody from "discourse/float-kit/components/d-float-body";
import {
  type FloatCallback,
  TOOLTIP,
  type TooltipOptions,
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

// The subset of arguments that mirror a tooltip's option bag. Built as a
// `Partial<Omit<…>>` over `TooltipOptions` (defined in `constants.ts`), so the
// arguments track the options automatically: a field added there is accepted here
// for free, with no second list to keep in sync. The three omitted fields are
// re-declared to narrow their generic `TooltipOptions` types (`data: unknown`, a
// `Data`-agnostic `component`, `onRegisterApi: FloatCallback | null`) to the
// component's `Data` and the concrete `DTooltipInstance`.
type DTooltipOptionArgs<Data> = Partial<
  Omit<TooltipOptions, "data" | "component" | "onRegisterApi">
> & {
  data?: Data;
  component?: ComponentLike<{ Args: { data?: Data; close?: FloatCallback } }>;
  onRegisterApi?: (instance: DTooltipInstance) => void;
};

interface DTooltipSignature<Data = unknown> {
  Element: HTMLSpanElement;
  Args: DTooltipOptionArgs<Data> & {
    // Arguments the component reads directly and forwards to the trigger button;
    // these are not keys of `TOOLTIP.options`.
    icon?: string;
    label?: string;
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
