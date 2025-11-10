import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import MountWidget from "discourse/components/mount-widget";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | Widget | button", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.siteSettings.deactivate_widgets_rendering = false;
  });

  test("icon only button", async function (assert) {
    this.set("args", { icon: "far-face-smile" });

    await render(
      <template><MountWidget @widget="button" @args={{this.args}} /></template>
    );

    assert.dom("button.btn.btn-icon.no-text").exists("has all the classes");
    assert.dom("button .d-icon.d-icon-far-face-smile").exists("has the icon");
  });

  test("icon and text button", async function (assert) {
    this.set("args", { icon: "plus", label: "topic.create" });

    await render(
      <template><MountWidget @widget="button" @args={{this.args}} /></template>
    );

    assert.dom("button.btn.btn-icon-text").exists("has all the classes");
    assert.dom("button .d-icon.d-icon-plus").exists("has the icon");
    assert.dom("button span.d-button-label").exists("has the label");
  });

  test("emoji and text button", async function (assert) {
    this.set("args", { emoji: "mega", label: "topic.create" });

    await render(
      <template><MountWidget @widget="button" @args={{this.args}} /></template>
    );

    assert.dom("button.widget-button").exists("renders the widget");
    assert.dom("button img.emoji").exists("it renders the emoji");
    assert.dom("button span.d-button-label").exists("it renders the label");
  });

  test("translatedLabel", async function (assert) {
    this.set("args", { translatedLabel: "foo bar" });

    await render(
      <template><MountWidget @widget="button" @args={{this.args}} /></template>
    );

    assert.dom("button span.d-button-label").hasText("foo bar");
  });

  test("translatedTitle", async function (assert) {
    this.set("args", { label: "topic.create", translatedTitle: "foo bar" });

    await render(
      <template><MountWidget @widget="button" @args={{this.args}} /></template>
    );

    assert.dom("button").hasAttribute("title", "foo bar");
  });

  test("translatedLabel skips no-text class in icon", async function (assert) {
    this.set("args", { icon: "plus", translatedLabel: "foo bar" });

    await render(
      <template><MountWidget @widget="button" @args={{this.args}} /></template>
    );

    assert
      .dom("button.btn.btn-icon-text")
      .doesNotHaveClass("no-text", "skips no-text class");
  });
});
