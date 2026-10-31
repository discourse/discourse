import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import DSelectTag from "discourse/ui-kit/select/recipes/tags/d-select-tag";
import ExpressionWrapper from "./expression-wrapper.gjs";

function tagValue(value) {
  if (Array.isArray(value)) {
    return value;
  }
  if (typeof value === "string" && value.length > 0) {
    return value.split(",").map((t) => t.trim());
  }
  return [];
}

export default class TagsControl extends Component {
  @service siteSettings;

  @action
  handleChange(tags) {
    const names = (tags || []).map((t) =>
      typeof t === "string" ? t : t.name || t.id || t
    );
    this.args.field.set(names);
  }

  <template>
    <ExpressionWrapper
      @dynamicValueHint={{@dynamicValueHint}}
      @field={{@field}}
      @placeholder={{@placeholder}}
      @schema={{@schema}}
      @session={{@session}}
      @supportsExpression={{@supportsExpression}}
    >
      {{#if this.siteSettings.enable_new_select_controls}}
        {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
        <DSelectTag
          @allowCreate={{true}}
          @describedBy={{@field.describedBy}}
          @disabled={{@field.disabled}}
          @emit="names"
          @id={{@field.id}}
          @invalid={{if @field.error true false}}
          @legacyKind="mini-tag-chooser"
          @multiple={{true}}
          @onChange={{this.handleChange}}
          @texts={{hash ariaLabel=@field.title}}
          @value={{tagValue @field.value}}
        />
      {{else}}
        {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
        <MiniTagChooser
          @onChange={{this.handleChange}}
          @value={{tagValue @field.value}}
        />
      {{/if}}
    </ExpressionWrapper>
  </template>
}
