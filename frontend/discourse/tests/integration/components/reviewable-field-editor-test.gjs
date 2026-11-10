import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ReviewableFieldEditor from "discourse/components/reviewable-field-editor";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | ReviewableFieldEditor", function (hooks) {
  setupRenderingTest(hooks);

  test("reports an edit", async function (assert) {
    const changes = [];
    const valueChanged = (event) => changes.push(event.target.value);

    await render(
      <template>
        <ReviewableFieldEditor @value="first" @valueChanged={{valueChanged}} />
      </template>
    );

    assert.dom(".d-editor-input").hasValue("first");

    await fillIn(".d-editor-input", "second");

    assert.strictEqual(changes.at(-1), "second", "passes the edited value up");
  });
});
