import Component from "@glimmer/component";
import { modifier } from "ember-modifier";
import { tracked } from "@glimmer/tracking";
import icon from "discourse-common/helpers/d-icon";
import { inject as service } from "@ember/service";
import DFloatBody from "float-kit/components/d-float-body";
import concatClass from "discourse/helpers/concat-class";
import DTooltipInstance from "float-kit/lib/d-tooltip-instance";
import { getOwner } from "@ember/application";
import and from "truth-helpers/helpers/and";

export default class DTooltip extends Component {
  <template>
    {{! template-lint-disable modifier-name-case }}
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
      {{this.registerTrigger}}
      ...attributes
    >
      <div class="fk-d-tooltip__trigger-container">
        {{#if (has-block "trigger")}}
          <div>
            {{yield this.componentArgs to="trigger"}}
          </div>
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
      </div>
    </span>

    {{#if this.tooltipInstance.expanded}}
      <DFloatBody
        @instance={{this.tooltipInstance}}
        @trapTab={{and this.options.interactive this.options.trapTab}}
        @mainClass="fk-d-tooltip"
        @innerClass="fk-d-tooltip__inner-content"
        @role="tooltip"
        @inline={{this.options.inline}}
        @portalOutletElement={{this.tooltip.portalOutletElement}}
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

  @service tooltip;

  @tracked tooltipInstance = null;

  registerTrigger = modifier((element) => {
    const options = {
      ...this.args,
      ...{
        listeners: true,
        beforeTrigger: () => {
          this.tooltip.close();
        },
      },
    };
    const instance = new DTooltipInstance(getOwner(this), element, options);

    this.tooltipInstance = instance;

    return () => {
      instance.destroy();

      if (this.isDestroying) {
        this.tooltipInstance = null;
      }
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
}
