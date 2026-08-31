import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import {
  composeOptionUtterance,
  navigablePositions,
  optionUtterances,
} from "discourse/tests/helpers/aria-patterns/utterances";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DSelect from "discourse/ui-kit/select/d-select";

// What a reader actually hears when landing on a row, as opposed to which attributes are present.
//
// The fixture deliberately includes a disabled row in the middle, because that is the shape of the
// open "a skipped row still occupies a position" item: every attribute is correct and the composed
// phrase still misleads, announcing a position the cursor can never land on.

const ITEMS = [
  { id: 1, name: "Watching" },
  { id: 2, name: "Tracking" },
  { id: 3, name: "Muted", disabled: true },
  { id: 4, name: "Normal" },
];

class Host extends Component {
  @tracked value = null;

  @action
  onChange(value) {
    this.value = value;
  }

  <template>
    <DSelect
      @items={{ITEMS}}
      @value={{this.value}}
      @onChange={{this.onChange}}
      @variant="static"
      @placeholder="Pick one"
    >
      <:selection as |item|>{{item.name}}</:selection>
      <:item as |item|>{{item.name}}</:item>
    </DSelect>
  </template>
}

module("Integration | ui-kit | select | DSelect utterances", function (hooks) {
  setupRenderingTest(hooks);

  test("a row speaks its name and its position in the set", async function (assert) {
    await render(<template><Host /></template>);
    await click("[role='combobox']");

    const first = document.querySelector("[role='option']");

    assert.strictEqual(
      composeOptionUtterance(first),
      "Watching, 1 of 4",
      "the first row names itself and where it sits"
    );
  });

  test("the accessible name is computed, not read as text", async function (assert) {
    await render(<template><Host /></template>);
    await click("[role='combobox']");

    // Every row carries a visually-hidden hint in its subtree. Reading textContent would fold that
    // into the name; computing it per ACCNAME is what a reader actually gets.
    const utterances = optionUtterances();

    assert.true(
      utterances.every((phrase) => phrase.split(",")[0].trim().length > 0),
      `every row resolves a name — got ${JSON.stringify(utterances)}`
    );
  });

  test("a disabled row is spoken as unavailable", async function (assert) {
    await render(<template><Host /></template>);
    await click("[role='combobox']");

    const spoken = optionUtterances();

    assert.true(
      spoken.some((phrase) => phrase.includes("unavailable")),
      `the disabled row announces its state — got ${JSON.stringify(spoken)}`
    );
  });

  // The assertion that motivated this helper, and a reproduction of an OPEN defect: with the fixture
  // above it observes [1,2,4], because the disabled row consumes position 3 while the cursor can
  // never land on it. Every row also claims "of 4" where only three are reachable. That is the
  // miniature of "Watching, 4 of 6" one press away from "6 of 6" in
  // SANDBOX-A11Y-REMEDIATION.md, which until now was findable only by listening.
  //
  // `todo`, not `skip`: it stays executable and reports green while the defect exists, then FAILS the
  // moment someone fixes it, which is the prompt to promote it to a plain `test`. Asserting the
  // observed [1,2,4] instead would encode the bug, and that doc has a section on tests that did.
  //
  // The invariant is deliberately agnostic about the remedy — what a reader hears must match the rows
  // they can visit — so either candidate fix satisfies it: make disabled rows navigable, or stop them
  // consuming positions.
  test.todo(
    "reachable rows speak contiguous positions",
    async function (assert) {
      await render(<template><Host /></template>);
      await click("[role='combobox']");

      const positions = navigablePositions();
      const contiguous = positions.every(
        (position, index) => position === index + 1
      );

      assert.true(
        contiguous,
        `reachable rows announced ${JSON.stringify(positions)}; a gap means an unreachable row ` +
          `consumed a position, so the count a reader hears disagrees with the rows they can visit`
      );
    }
  );

  // Guards the helper itself: without this, the assertion above would pass vacuously on a fixture
  // whose rows never report a position at all.
  test("the helper reads positions rather than inventing them", async function (assert) {
    await render(<template><Host /></template>);
    await click("[role='combobox']");

    assert.deepEqual(
      navigablePositions().filter((position) => position === null),
      [],
      "every reachable row yielded a parsed position"
    );
  });
});
