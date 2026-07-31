import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { findAll } from "@ember/test-helpers";
import DSelect from "discourse/ui-kit/select/d-select";

export const ITEMS = [
  { id: 1, name: "Apple" },
  { id: 2, name: "Banana" },
  { id: 3, name: "Cherry pie" },
];

// A controlled host: it owns @value and updates it from @onChange, exactly as a
// consumer (or FormKit) does.
export class Host extends Component {
  @tracked value = this.args.value ?? null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @items={{ITEMS}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @variant={{@variant}}
      @placeholder="Pick one"
      @identifier="test-select"
    >
      <:selection as |item|>{{item.name}}</:selection>
      <:item as |item|>{{item.name}}</:item>
    </DSelect>
  </template>
}

export class DefaultHost extends Component {
  @tracked value = this.args.value ?? (this.args.multiple ? [] : null);

  get items() {
    return this.args.items ?? ITEMS;
  }

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @items={{this.items}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @variant={{@variant}}
      @multiple={{@multiple}}
      @labelField={{@labelField}}
      @placeholder="Pick one"
    />
  </template>
}

export class MultiLimitsHost extends Component {
  @tracked value = this.args.value ?? [];

  get items() {
    return this.args.items ?? ITEMS;
  }

  @action
  onChange(value, payload) {
    this.args.onChange?.(value, payload);
    this.value = value;
  }

  <template>
    <DSelect
      @multiple={{true}}
      @items={{this.items}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @maximum={{@maximum}}
      @minimum={{@minimum}}
      @allowCreate={{@allowCreate}}
      @createItem={{@createItem}}
      @clearable={{@clearable}}
      @placeholder="Pick some"
      @identifier="test-multi-limits"
    >
      <:selection as |item|>{{item.name}}</:selection>
      <:item as |item|>{{item.name}}</:item>
    </DSelect>
  </template>
}

export function optionWithText(text) {
  return findAll("[role='option']").find((option) =>
    option.textContent.includes(text)
  );
}
