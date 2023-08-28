import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { count, exists } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import { resetPostMenuExtraButtons } from "discourse/widgets/post-menu";
import { withPluginApi } from "discourse/lib/plugin-api";
import { createWidget } from "discourse/widgets/widget";
import { h } from "virtual-dom";

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

  createWidget("post-menu-replacement", {
    html(attrs) {
      return h("h1.post-menu-replacement", {}, attrs.id);
    },
  });

  test("buttons are replaced when shouldRender is true", async function (assert) {
    this.set("args", { id: 1, canCreatePost: true });

    withPluginApi("0.14.0", (api) => {
      api.replacePostMenuButton("reply", {
        name: "post-menu-replacement",
        buildAttrs: (widget) => {
          return widget.attrs;
        },
        shouldRender: (widget) => widget.attrs.id === 1, // true!
      });
    });

    await render(hbs`<MountWidget @widget="post-menu" @args={{this.args}} />`);

    assert.ok(exists("h1.post-menu-replacement"), "replacement is rendered");
    assert.ok(!exists(".actions .reply"), "reply button is replaced button");
  });

  test("buttons are not replaced when shouldRender is false", async function (assert) {
    this.set("args", { id: 1, canCreatePost: true, canRemoveReply: false });

    withPluginApi("0.14.0", (api) => {
      api.replacePostMenuButton("reply", {
        name: "post-menu-replacement",
        buildAttrs: (widget) => {
          return widget.attrs;
        },
        shouldRender: (widget) => widget.attrs.id === 102323948, // false!
      });
    });

    await render(hbs`<MountWidget @widget="post-menu" @args={{this.args}} />`);

    assert.ok(
      !exists("h1.post-menu-replacement"),
      "replacement is not rendered"
    );
    assert.ok(exists(".actions .reply"), "reply button is present");
  });
});
