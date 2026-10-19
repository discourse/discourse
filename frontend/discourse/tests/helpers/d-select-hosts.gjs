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
      @identifier="test-select"
      @items={{ITEMS}}
      @kind="test-select"
      @onChange={{this.onChange}}
      @placeholder="Pick one"
      @value={{this.value}}
      @variant={{@variant}}
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
      @labelField={{@labelField}}
      @multiple={{@multiple}}
      @onChange={{this.onChange}}
      @placeholder="Pick one"
      @value={{this.value}}
      @variant={{@variant}}
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
      @allowCreate={{@allowCreate}}
      @clearable={{@clearable}}
      @createItem={{@createItem}}
      @identifier="test-multi-limits"
      @items={{this.items}}
      @kind="test-multi-limits"
      @maximum={{@maximum}}
      @minimum={{@minimum}}
      @multiple={{true}}
      @onChange={{this.onChange}}
      @placeholder="Pick some"
      @value={{this.value}}
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

let probedSelectEngine;

/**
 * A `DSelect` that records its engine, for tests that drive engine internals (`revealMore`,
 * `reload`) which no consumer-facing surface exposes.
 */
export class EngineProbe extends DSelect {
  constructor() {
    super(...arguments);
    probedSelectEngine = this.engine;
  }
}

/** The engine of the most recently constructed {@link EngineProbe}. */
export function probedEngine() {
  return probedSelectEngine;
}
