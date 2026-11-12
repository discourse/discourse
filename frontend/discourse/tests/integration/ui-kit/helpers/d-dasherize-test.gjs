import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dDasherize from "discourse/ui-kit/helpers/d-dasherize";

module("Integration | ui-kit | Helper | dDasherize", function (hooks) {
  setupRenderingTest(hooks);

  test("dasherizes a camelized value", async function (assert) {
    await render(
      <template>
        <span class="output">{{dDasherize "fooBar"}}</span>
      </template>
    );

    assert.dom(".output").hasText("foo-bar");
  });

  test("turns only the first dot into a dash", async function (assert) {
    await render(
      <template>
        <span class="output">{{dDasherize "foo.bar.baz"}}</span>
      </template>
    );

    assert.dom(".output").hasText("foo-bar.baz");
  });

  test("treats a missing value as empty", async function (assert) {
    await render(
      <template>
        <span class="output">{{dDasherize undefined}}</span>
      </template>
    );

    assert.dom(".output").hasText("");
  });
});
