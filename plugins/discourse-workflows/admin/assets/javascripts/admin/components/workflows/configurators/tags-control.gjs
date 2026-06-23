import Component from "@glimmer/component";
import { action } from "@ember/object";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import ExpressionWrapper from "./expression-wrapper";

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
  @action
  handleChange(tags) {
    const names = (tags || []).map((t) =>
      typeof t === "string" ? t : t.name || t.id || t
    );
    this.args.field.set(names);
  }

  <template>
    <ExpressionWrapper
      @field={{@field}}
      @schema={{@schema}}
      @supportsExpression={{@supportsExpression}}
      @placeholder={{@placeholder}}
      @dynamicValueHint={{@dynamicValueHint}}
      @session={{@session}}
    >
      <MiniTagChooser
        @value={{tagValue @field.value}}
        @onChange={{this.handleChange}}
      />
    </ExpressionWrapper>
  </template>
}
