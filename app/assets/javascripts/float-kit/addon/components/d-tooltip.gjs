import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { and } from "truth-helpers";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse-common/helpers/d-icon";
import DFloatBody from "float-kit/components/d-float-body";
import { TOOLTIP } from "float-kit/lib/constants";
import DTooltipInstance from "float-kit/lib/d-tooltip-instance";

export default class DTooltip extends Component {
  @service tooltip;
  @service internalTooltip;

  tooltipInstance = new DTooltipInstance(getOwner(this), {
    ...this.allowedProperties,
    autoUpdate: true,
    listeners: true,
  });

  registerTrigger = modifier((element) => {
    this.tooltipInstance.trigger = element;
    this.options.onRegisterApi?.(this.tooltipInstance);

    return () => {
      this.tooltipInstance.destroy();
    };
  });

  get options() {
    return this.tooltipInstance?.options;
  }

  get componentArgs() {
    return {
      close: this.tooltip.close,
      data: this.options.data,
    };
  }

  get allowedProperties() {
    const properties = {};
    for (const [key, value] of Object.entries(TOOLTIP.options)) {
      properties[key] = this.args[key] ?? value;
    }
    return properties;
  }

  <template>
    <span
      {{this.registerTrigger this.allowedProperties}}
      class={{concatClass
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
        {{#if (has-block "trigger")}}
          {{yield this.componentArgs to="trigger"}}
        {{else}}
          {{#if @icon}}
            <span class="fk-d-tooltip__icon">
              {{~icon @icon~}}
            </span>
          {{/if}}
          {{#if @label}}
            <span class="fk-d-tooltip__label">{{@label}}</span>
          {{/if}}
        {{/if}}
      </span>
    </span>

    {{#if this.tooltipInstance.expanded}}
      <DFloatBody
        @instance={{this.tooltipInstance}}
        @trapTab={{and this.options.interactive this.options.trapTab}}
        @mainClass={{concatClass
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
    {{/if}}
  </template>
}
