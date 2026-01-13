import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import ListSetting from "discourse/select-kit/components/list-setting";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";

module("Integration | Component | select-kit/list-setting", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.set("subject", selectKit());
  });

  test("default", async function (assert) {
    this.set("value", ["bold", "italic"]);
    this.set("choices", ["bold", "italic", "underline"]);

    await render(
      <template>
        <ListSetting @value={{this.value}} @choices={{this.choices}} />
      </template>
    );

    assert.strictEqual(this.subject.header().name(), "bold,italic");
    assert.strictEqual(this.subject.header().value(), "bold,italic");

    await this.subject.expand();

    assert.strictEqual(this.subject.rows().length, 1);
    assert.strictEqual(this.subject.rowByIndex(0).value(), "underline");
  });
});
