import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import {
  auditCombobox,
  auditedOptionCount,
} from "discourse/tests/helpers/aria-patterns/axe";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DSelect from "discourse/ui-kit/select/d-select";

// The axe floor. Deliberately thin: axe cannot see a wrong-but-valid role, and its whole
// `aria-activedescendant` check is that the id resolves to *something*, so it is blind to the
// cursor defects this widget actually regresses on. Its value is catching a malformed attribute or
// a missing accessible name early — the APG pattern suite asserts the pattern itself.

const ITEMS = [
  { id: 1, name: "Apple" },
  { id: 2, name: "Banana" },
  { id: 3, name: "Cherry pie" },
];

class Host extends Component {
  @tracked value = this.args.multiple ? [] : null;

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
      @multiple={{@multiple}}
      @label="Fruit"
      @placeholder="Pick one"
    >
      <:selection as |item|>{{item.name}}</:selection>
      <:item as |item|>{{item.name}}</:item>
    </DSelect>
  </template>
}

module("Integration | ui-kit | select | DSelect axe floor", function (hooks) {
  setupRenderingTest(hooks);

  // The guard, and the reason the rest of this module means anything. The panel is portaled out of
  // the trigger, so an audit scoped to the trigger alone reaches zero options and still reports
  // clean — which is precisely how this module first shipped. Assert the audit can see rows before
  // trusting any result that says it found none.
  test("the audit actually reaches the portaled options", async function (assert) {
    await render(<template><Host @variant="static" /></template>);
    await click("[role='combobox']");

    assert.true(
      auditedOptionCount() >= ITEMS.length,
      `the audited scope contains the rows — saw ${auditedOptionCount()} of ${ITEMS.length}`
    );
  });

  test("a closed select has no gated violations", async function (assert) {
    await render(<template><Host @variant="static" /></template>);
    await auditCombobox(assert);
  });

  test("an open select-only listbox has no gated violations", async function (assert) {
    await render(<template><Host @variant="static" /></template>);
    await click("[role='combobox']");
    await auditCombobox(assert);
  });

  test("an open typeahead has no gated violations", async function (assert) {
    await render(<template><Host @variant="typeahead" /></template>);
    await click("[role='combobox']");
    await auditCombobox(assert);
  });

  test("an open multi-select has no gated violations", async function (assert) {
    await render(
      <template><Host @variant="typeahead" @multiple={{true}} /></template>
    );
    await click("[role='combobox']");
    await auditCombobox(assert);
  });
});
