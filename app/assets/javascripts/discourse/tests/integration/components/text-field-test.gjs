import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import TextField from "discourse/components/text-field";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | text-field", function (hooks) {
  setupRenderingTest(hooks);

  test("renders correctly with no properties set", async function (assert) {
    await render(<template><TextField /></template>);

    assert.dom("input[type=text]").exists();
  });

  test("support a placeholder", async function (assert) {
    await render(
      <template><TextField @placeholderKey="placeholder.i18n.key" /></template>
    );

    assert.dom("input[type=text]").exists();
    assert
      .dom("input")
      .hasAttribute("placeholder", "[en.placeholder.i18n.key]");
  });

  test("sets the dir attribute to auto when mixed text direction enabled", async function (assert) {
    this.siteSettings.support_mixed_text_direction = true;

    await render(
      <template><TextField @value="זהו שם עברי עם מקום עברי" /></template>
    );

    assert.dom("input").hasAttribute("dir", "auto");
  });

  test("supports onChange", async function (assert) {
    const self = this;

    this.called = false;
    this.newValue = null;
    this.set("value", "hello");
    this.set("changed", (v) => {
      this.newValue = v;
      this.called = true;
    });

    await render(
      <template>
        <TextField
          class="tf-test"
          @value={{self.value}}
          @onChange={{self.changed}}
        />
      </template>
    );

    await fillIn(".tf-test", "hello");
    assert.false(this.called);

    await fillIn(".tf-test", "new text");
    assert.true(this.called);
    assert.strictEqual(this.newValue, "new text");
  });

  test("supports onChangeImmediate", async function (assert) {
    const self = this;

    this.called = false;
    this.newValue = null;
    this.set("value", "old");
    this.set("changed", (v) => {
      this.newValue = v;
      this.called = true;
    });

    await render(
      <template>
        <TextField
          class="tf-test"
          @value={{self.value}}
          @onChangeImmediate={{self.changed}}
        />
      </template>
    );

    await fillIn(".tf-test", "old");
    assert.false(this.called);

    await fillIn(".tf-test", "no longer old");
    assert.true(this.called);
    assert.strictEqual(this.newValue, "no longer old");
  });
});
