import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewableFieldText from "discourse/components/reviewable-field-text";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | ReviewableFieldText", function (hooks) {
  setupRenderingTest(hooks);

  test("reports an edit", async function (assert) {
    const changes = [];
    const valueChanged = (event) => changes.push(event.target.value);

    await render(
      <template>
        <ReviewableFieldText @value="first" @valueChanged={{valueChanged}} />
      </template>
    );

    assert.dom(".reviewable-input-text").hasValue("first");

    await fillIn(".reviewable-input-text", "second");

    assert.deepEqual(changes, ["second"], "passes the edited value up");
    assert.dom(".reviewable-input-text").hasValue("second");
  });
});
