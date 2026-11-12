import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dFormatDuration from "discourse/ui-kit/helpers/d-format-duration";

module("Integration | ui-kit | Helper | dFormatDuration", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a tiny duration", async function (assert) {
    await render(
      <template>
        <div class="test">{{dFormatDuration 120}}</div>
      </template>
    );

    assert.dom(".test").hasText("2m");
  });

  test("renders a dash for a missing duration", async function (assert) {
    await render(
      <template>
        <div class="test">{{dFormatDuration null}}</div>
      </template>
    );

    assert.dom(".test").hasText("—");
  });
});
