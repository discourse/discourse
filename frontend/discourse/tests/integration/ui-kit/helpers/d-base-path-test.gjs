import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setPrefix } from "discourse/lib/get-url";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dBasePath from "discourse/ui-kit/helpers/d-base-path";

module("Integration | ui-kit | Helper | dBasePath", function (hooks) {
  setupRenderingTest(hooks);

  test("renders the base path", async function (assert) {
    setPrefix("/forum");

    await render(
      <template>
        <div class="test">{{dBasePath}}</div>
      </template>
    );

    assert.dom(".test").hasText("/forum");
  });

  test("renders nothing without a base path", async function (assert) {
    setPrefix("");

    await render(
      <template>
        <div class="test">{{dBasePath}}</div>
      </template>
    );

    assert.dom(".test").hasNoText();
  });
});
