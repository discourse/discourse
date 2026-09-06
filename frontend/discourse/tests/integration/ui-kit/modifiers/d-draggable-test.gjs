import { render, resetOnerror, setupOnerror } from "@ember/test-helpers";
import { module, test } from "qunit";
import DeprecationWorkflow from "discourse/deprecation-workflow";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  restoreCountingDeprecation,
  skipCountingDeprecation,
} from "discourse/tests/helpers/deprecation-counter";
import {
  disableRaiseOnDeprecationQUnitResult,
  enableRaiseOnDeprecationQUnitResult,
} from "discourse/tests/helpers/raise-on-deprecation";
import dDraggable from "discourse/ui-kit/modifiers/d-draggable";

const DEPRECATION_ID = "discourse.ui-kit.d-draggable";

module("Integration | ui-kit | modifiers | dDraggable", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    // Reaching the modifier both pushes a failed assertion and throws. Only the
    // assertion is suppressed here; the throw is what these tests are about.
    disableRaiseOnDeprecationQUnitResult();
    skipCountingDeprecation(DEPRECATION_ID);
  });

  hooks.afterEach(function () {
    resetOnerror();
    enableRaiseOnDeprecationQUnitResult();
    restoreCountingDeprecation(DEPRECATION_ID);
  });

  test("using it raises, naming the id that tracks remaining usage", async function (assert) {
    let raised = null;
    setupOnerror((error) => (raised = error));

    await render(
      <template>
        <div {{dDraggable}}></div>
      </template>
    );

    // Asserted after the render rather than inside the handler, so a render that
    // raises nothing fails here instead of silently making no assertion.
    assert.true(
      raised?.message.includes(DEPRECATION_ID),
      "the raised error names the deprecation id"
    );
  });

  test("nothing silences the deprecation, so a usage in core or a preinstalled plugin fails CI", function (assert) {
    assert.true(
      DeprecationWorkflow.shouldThrow(DEPRECATION_ID, true),
      "an id with no workflow entry raises under RAISE_ON_DEPRECATION"
    );
  });
});
