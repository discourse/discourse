import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import TextField from "discourse/components/text-field";
import { resetSiteDirForTesting } from "discourse/lib/text-direction";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | text-field", function (hooks) {
  setupRenderingTest(hooks);

  let originalHtmlDir;
  let originalHtmlIsRtl;

  hooks.beforeEach(function () {
    originalHtmlDir = document.documentElement.getAttribute("dir");
    originalHtmlIsRtl = document.documentElement.classList.contains("rtl");
  });

  hooks.afterEach(function () {
    if (originalHtmlDir === null) {
      document.documentElement.removeAttribute("dir");
    } else {
      document.documentElement.setAttribute("dir", originalHtmlDir);
    }

    document.documentElement.classList.toggle("rtl", originalHtmlIsRtl);
    resetSiteDirForTesting();
  });

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

  test("uses site direction if the input is empty and `auto` if the input isn't empty", async function (assert) {
    this.siteSettings.support_mixed_text_direction = true;
    document.documentElement.removeAttribute("dir");
    document.documentElement.classList.add("rtl");
    resetSiteDirForTesting();

    await render(<template><TextField /></template>);

    assert.dom("input").hasAttribute("dir", "rtl");

    await fillIn("input", "123");
    assert.dom("input").hasAttribute("dir", "auto");

    await fillIn("input", "hello");
    assert.dom("input").hasAttribute("dir", "auto");

    await fillIn("input", "");
    assert.dom("input").hasAttribute("dir", "rtl");
  });

  test("supports onChange", async function (assert) {
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
          @value={{this.value}}
          @onChange={{this.changed}}
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
          @value={{this.value}}
          @onChangeImmediate={{this.changed}}
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
