import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dLoadingSpinner, {
  renderSpinner,
  spinnerHTML,
} from "discourse/ui-kit/helpers/d-loading-spinner";

module("Integration | ui-kit | Helper | dLoadingSpinner", function (hooks) {
  setupRenderingTest(hooks);

  test("renders a spinner", async function (assert) {
    await render(<template>{{dLoadingSpinner}}</template>);

    assert.dom(".spinner").hasAttribute("class", "spinner");
  });

  test("adds the size as a class", async function (assert) {
    await render(<template>{{dLoadingSpinner size="small"}}</template>);

    assert.dom(".spinner").hasAttribute("class", "spinner small");
  });

  test("renderSpinner adds an extra class", function (assert) {
    assert.strictEqual(
      renderSpinner("large"),
      "<div class='spinner large'></div>"
    );
  });

  test("spinnerHTML is a plain spinner", function (assert) {
    assert.strictEqual(spinnerHTML, "<div class='spinner'></div>");
  });
});
