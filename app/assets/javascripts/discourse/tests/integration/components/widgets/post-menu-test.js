import { click, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { h } from "virtual-dom";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { count } from "discourse/tests/helpers/qunit-helpers";
import { resetPostMenuExtraButtons } from "discourse/widgets/post-menu";
import { createWidget } from "discourse/widgets/widget";

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
          icon: "mug-saucer",
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

  test("add extra button with feedback", async function (assert) {
    this.set("args", {});

    let testPost = null;

    withPluginApi("0.14.0", (api) => {
      api.addPostMenuButton("coffee", () => {
        return {
          action: ({ post, showFeedback }) => {
            testPost = post;
            showFeedback("coffee.drink");
          },
          icon: "mug-saucer",
          className: "hot-coffee",
          title: "coffee.title",
          position: "first",
          actionParam: { id: 123 }, // hack for testing
        };
      });
    });

    await render(hbs`
       <article data-post-id="123">
          <MountWidget @widget="post-menu" @args={{this.args}} />
       </article>`);

    await click(".hot-coffee");

    assert.strictEqual(testPost.id, 123, "callback was called with post");
    assert.strictEqual(
      count(".post-action-feedback-button"),
      1,
      "It renders feedback"
    );

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

    assert.dom(".actions .reply").doesNotExist("removes reply button");
  });

  test("does not remove button", async function (assert) {
    this.set("args", { canCreatePost: true, canRemoveReply: false });

    withPluginApi("0.14.0", (api) => {
      api.removePostMenuButton("reply", (attrs) => {
        return attrs.canRemoveReply;
      });
    });

    await render(hbs`<MountWidget @widget="post-menu" @args={{this.args}} />`);

    assert.dom(".actions .reply").exists("does not remove reply button");
  });

  test("removes button", async function (assert) {
    this.set("args", { canCreatePost: true });

    withPluginApi("0.14.0", (api) => {
      api.removePostMenuButton("reply");
    });

    await render(hbs`<MountWidget @widget="post-menu" @args={{this.args}} />`);

    assert.dom(".actions .reply").doesNotExist("removes reply button");
  });

  test("removes button when any callback evaluates to true", async function (assert) {
    this.set("args", {});

    withPluginApi("0.14.0", (api) => {
      api.removePostMenuButton("reply", () => true);
      api.removePostMenuButton("reply", () => false);
    });

    await render(hbs`<MountWidget @widget="post-menu" @args={{this.args}} />`);

    assert.dom(".actions .reply").doesNotExist("removes reply button");
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

    assert.dom("h1.post-menu-replacement").exists("replacement is rendered");
    assert
      .dom(".actions .reply")
      .doesNotExist("reply button is replaced button");
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

    assert
      .dom("h1.post-menu-replacement")
      .doesNotExist("replacement is not rendered");
    assert.dom(".actions .reply").exists("reply button is present");
  });
});
