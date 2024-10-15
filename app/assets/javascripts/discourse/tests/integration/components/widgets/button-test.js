import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | Widget | button", function (hooks) {
  setupRenderingTest(hooks);

  test("icon only button", async function (assert) {
    this.set("args", { icon: "far-face-smile" });

    await render(hbs`<MountWidget @widget="button" @args={{this.args}} />`);

    assert.ok(exists("button.btn.btn-icon.no-text"), "it has all the classes");
    assert.ok(
      exists("button .d-icon.d-icon-far-face-smile"),
      "it has the icon"
    );
  });

  test("icon and text button", async function (assert) {
    this.set("args", { icon: "plus", label: "topic.create" });

    await render(hbs`<MountWidget @widget="button" @args={{this.args}} />`);

    assert.ok(exists("button.btn.btn-icon-text"), "it has all the classes");
    assert.ok(exists("button .d-icon.d-icon-plus"), "it has the icon");
    assert.ok(exists("button span.d-button-label"), "it has the label");
  });

  test("emoji and text button", async function (assert) {
    this.set("args", { emoji: "mega", label: "topic.create" });

    await render(hbs`<MountWidget @widget="button" @args={{this.args}} />`);

    assert.ok(exists("button.widget-button"), "renders the widget");
    assert.ok(exists("button img.emoji"), "it renders the emoji");
    assert.ok(exists("button span.d-button-label"), "it renders the label");
  });

  test("text only button", async function (assert) {
    this.set("args", { label: "topic.create" });

    await render(hbs`<MountWidget @widget="button" @args={{this.args}} />`);

    assert.ok(exists("button.btn.btn-text"), "it has all the classes");
    assert.ok(exists("button span.d-button-label"), "it has the label");
  });

  test("translatedLabel", async function (assert) {
    this.set("args", { translatedLabel: "foo bar" });

    await render(hbs`<MountWidget @widget="button" @args={{this.args}} />`);

    assert.dom("button span.d-button-label").hasText("foo bar");
  });

  test("translatedTitle", async function (assert) {
    this.set("args", { label: "topic.create", translatedTitle: "foo bar" });

    await render(hbs`<MountWidget @widget="button" @args={{this.args}} />`);

    assert.dom("button").hasAttribute("title", "foo bar");
  });

  test("translatedLabel skips no-text class in icon", async function (assert) {
    this.set("args", { icon: "plus", translatedLabel: "foo bar" });

    await render(hbs`<MountWidget @widget="button" @args={{this.args}} />`);

    assert.ok(!exists("button.btn.btn-icon.no-text"), "skips no-text class");
  });
});
