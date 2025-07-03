import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { setupRenderingTest } from "ember-qunit";
import { module, test } from "qunit";
import PostMenuFlagButton from "discourse/components/post/menu/buttons/flag"; // Corrected path
import { withPluginApi } from "discourse/lib/plugin-api";

module("Integration | Component | Post Menu Flag Button", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    // Baseline args and helper for shouldRender to be true initially
    this.args = {
      post: {
        canFlag: true,
        hidden: false,
        reviewable_id: null, // Not relying on this for baseline true
        // For rendered component tests
        reviewable_score_pending_count: 0,
        reviewable_score_count: 0,
        currentUser: false, // post.currentUser (user has not flagged this post)
      },
    };

    this.helper = {
      siteSettings: { reviewable_claiming_enabled: true },
      currentUser: { id: 1, username: "test_user" }, // Updated mock user object
    };
  });

  test("shouldRender returns true with baseline args and helper", function (assert) {
    assert.true(
      PostMenuFlagButton.shouldRender(this.args, this.helper),
      "shouldRender is true by default with baseline setup"
    );
  });

  test("shouldRender returns false when 'flag-button-render-decision' transformer returns false", function (assert) {
    withPluginApi("0.1", (api) => {
      api.registerValueTransformer("flag-button-render-decision", () => false);
    });
    assert.false(
      PostMenuFlagButton.shouldRender(this.args, this.helper),
      "shouldRender is false due to transformer"
    );
  });

  test("'flag-button-disabled-state' transformer to true causes DButton to be disabled", async function (assert) {
    withPluginApi("0.1", (api) => {
      api.registerValueTransformer("flag-button-render-decision", () => true); // Ensure component renders
      api.registerValueTransformer("flag-button-disabled-state", () => true);
    });

    this.set("postForRender", this.args.post);
    await render(
      hbs`<Post::Menu::Buttons::Flag @post={{this.postForRender}} />`
    );

    assert
      .dom("button.create-flag")
      .isDisabled("Button is disabled by transformer");
  });

  test("'flag-button-dynamic-class' transformer applies the given style", async function (assert) {
    const testClass = "my-special-flag-style";
    withPluginApi("0.1", (api) => {
      api.registerValueTransformer("flag-button-render-decision", () => true); // Ensure component renders
      api.registerValueTransformer(
        "flag-button-dynamic-class",
        () => testClass
      );
    });

    this.set("postForRender", this.args.post);
    await render(
      hbs`<Post::Menu::Buttons::Flag @post={{this.postForRender}} />`
    );

    assert
      .dom("button.create-flag")
      .hasClass(testClass, "Button has the custom class from transformer");
  });
});
