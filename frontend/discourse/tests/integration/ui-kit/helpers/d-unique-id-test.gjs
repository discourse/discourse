import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dUniqueId from "discourse/ui-kit/helpers/d-unique-id";

const UUID_V4 =
  /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

module("Integration | ui-kit | Helper | dUniqueId", function (hooks) {
  setupRenderingTest(hooks);

  test("returns a version 4 UUID", async function (assert) {
    await render(
      <template>
        {{#let (dUniqueId) as |id|}}
          <span class="output">{{id}}</span>
        {{/let}}
      </template>
    );

    assert.true(
      UUID_V4.test(document.querySelector(".output").textContent.trim()),
      "the id has the version 4 UUID shape"
    );
  });

  test("returns a different id on each call", function (assert) {
    assert.notStrictEqual(dUniqueId(), dUniqueId());
  });
});
