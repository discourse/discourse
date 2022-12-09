import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { count, exists } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import { resetPostMenuExtraButtons } from "discourse/widgets/post-menu";
import { withPluginApi } from "discourse/lib/plugin-api";

module("Integration | Component | Widget | post-menu", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    resetPostMenuExtraButtons();
  });

  test("add extra button", async function (assert) {
    this.set("args", {});
    withPluginApi("0.14.0", (api) => {
      api.addPostMenuButton("coffee", () => {
        return {
          action: "drinkCoffee",
          icon: "coffee",
          className: "hot-coffee",
          title: "coffee.title",
          position: "first",
        };
      });
    });

    await render(hbs`<MountWidget @widget="post-menu" @args={{this.args}} />`);

    assert.strictEqual(
      count(".actions .extra-buttons .hot-coffee"),
      1,
      "It renders extra button"
    );
  });

  test("removes button based on callback", async function (assert) {
    this.set("args", { canCreatePost: true, canRemoveReply: true });

    withPluginApi("0.14.0", (api) => {
      api.removePostMenuButton("reply", (attrs) => {
        return attrs.canRemoveReply;
      });
    });

    await render(hbs`<MountWidget @widget="post-menu" @args={{this.args}} />`);

    assert.ok(!exists(".actions .reply"), "it removes reply button");
  });

  test("does not remove button", async function (assert) {
    this.set("args", { canCreatePost: true, canRemoveReply: false });

    withPluginApi("0.14.0", (api) => {
      api.removePostMenuButton("reply", (attrs) => {
        return attrs.canRemoveReply;
      });
    });

    await render(hbs`<MountWidget @widget="post-menu" @args={{this.args}} />`);

    assert.ok(exists(".actions .reply"), "it does not remove reply button");
  });

  test("removes button", async function (assert) {
    this.set("args", { canCreatePost: true });

    withPluginApi("0.14.0", (api) => {
      api.removePostMenuButton("reply");
    });

    await render(hbs`<MountWidget @widget="post-menu" @args={{this.args}} />`);

    assert.ok(!exists(".actions .reply"), "it removes reply button");
  });

  test("removes button when any callback evaluates to true", async function (assert) {
    this.set("args", {});

    withPluginApi("0.14.0", (api) => {
      api.removePostMenuButton("reply", () => true);
      api.removePostMenuButton("reply", () => false);
    });

    await render(hbs`<MountWidget @widget="post-menu" @args={{this.args}} />`);

    assert.ok(!exists(".actions .reply"), "it removes reply button");
  });
});
