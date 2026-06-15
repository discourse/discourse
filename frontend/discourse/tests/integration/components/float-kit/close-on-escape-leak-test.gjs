import { on } from "@ember/modifier";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | FloatKit | leak repro", function (hooks) {
  setupRenderingTest(hooks);

  test("1 - click trigger that programmatically closes (language pattern)", async function (assert) {
    const tooltip = this.owner.lookup("service:tooltip");
    const onClick = () => tooltip.close("leak-repro");

    await render(
      <template>
        <DTooltip @identifier="leak-repro" @icon="gear" {{on "click" onClick}}>
          <:content>hello</:content>
        </DTooltip>
      </template>
    );

    await click(".fk-d-tooltip__trigger");
    await click(".fk-d-tooltip__trigger");
    assert.ok(true, "clicked twice like the language toggle test");
  });

  test("2 - no capture-phase keydown listener leaked from test 1", async function (assert) {
    const leaked = (window.__kdListeners ?? []).filter((l) => l.capture);
    assert.strictEqual(
      leaked.length,
      0,
      `leaked capture keydown listeners: ${leaked.map((l) => `${l.tag}:${l.name} addedBy="${l.test}"`).join(" || ")}`
    );
  });
});
