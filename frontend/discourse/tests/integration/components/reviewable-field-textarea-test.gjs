import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewableFieldTextarea from "discourse/components/reviewable-field-textarea";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | ReviewableFieldTextarea", function (hooks) {
  setupRenderingTest(hooks);

  test("reports an edit", async function (assert) {
    const changes = [];
    const valueChanged = (event) => changes.push(event.target.value);

    await render(
      <template>
        <ReviewableFieldTextarea
          @value="first"
          @valueChanged={{valueChanged}}
        />
      </template>
    );

    assert.dom(".reviewable-input-textarea").hasValue("first");

    await fillIn(".reviewable-input-textarea", "second");

    assert.deepEqual(changes, ["second"], "passes the edited value up");
    assert.dom(".reviewable-input-textarea").hasValue("second");
  });
});
