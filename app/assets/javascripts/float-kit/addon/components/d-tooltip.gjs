import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { getOwner } from "@ember/application";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
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

  registerTrigger = modifier((element) => {
    if (!this.tooltipInstance?.trigger) {
      next(() => {
        this.tooltipInstance.trigger = element;
        this.options.onRegisterApi?.(this.tooltipInstance);
      });
    }
  });

  @cached
  get tooltipInstance() {
    return new DTooltipInstance(getOwner(this), {
      ...this.allowedProperties(),
      ...{ autoUpdate: true, listeners: true },
    });
  }

  get options() {
    return this.tooltipInstance?.options;
  }

  get componentArgs() {
    return {
      close: this.tooltip.close,
      data: this.options.data,
    };
  }

  @action
  allowedProperties() {
    const properties = {};
    Object.keys(TOOLTIP.options).forEach((key) => {
      const value = TOOLTIP.options[key];
      properties[key] = this.args[key] ?? value;
    });
    return properties;
  }

  <template>
    <span
      class={{concatClass
        "fk-d-tooltip__trigger"
        (if this.tooltipInstance.expanded "-expanded")
      }}
      role="button"
      id={{this.tooltipInstance.id}}
      data-identifier={{this.options.identifier}}
      data-trigger
      aria-expanded={{if this.tooltipInstance.expanded "true" "false"}}
      {{this.registerTrigger (this.allowedProperties)}}
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
