import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { exists, query } from "discourse/tests/helpers/qunit-helpers";
import UserMenuReviewable from "discourse/models/user-menu-reviewable";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import I18n from "I18n";

function getReviewable(overrides = {}) {
  return UserMenuReviewable.create(
    Object.assign(
      {
        flagger_username: "sayo2",
        id: 17,
        pending: false,
        topic_fancy_title: "anything hello world",
        type: "ReviewableQueuedPost",
      },
      overrides
    )
  );
}

module(
  "Integration | Component | user-menu | reviewable-queued-post-item",
  function (hooks) {
    setupRenderingTest(hooks);

    const template = hbs`<UserMenu::ReviewableQueuedPostItem @item={{this.item}}/>`;

    test("doesn't escape topic_fancy_title because it's safe", async function (assert) {
      this.set(
        "item",
        getReviewable({
          topic_fancy_title: "This is safe title &lt;a&gt; :heart:",
        })
      );
      await render(template);
      const description = query(".reviewable-description");
      assert.strictEqual(
        description.textContent.trim(),
        I18n.t("user_menu.reviewable.new_post_in_topic", {
          title: "This is safe title <a>",
        })
      );
      assert.strictEqual(
        description.querySelectorAll("img.emoji").length,
        1,
        "emojis are rendered"
      );
    });

    test("escapes payload_title because it's not safe", async function (assert) {
      this.set(
        "item",
        getReviewable({
          topic_fancy_title: null,
          payload_title: "This is unsafe title <a> :heart:",
        })
      );
      await render(template);
      const description = query(".reviewable-description");
      assert.strictEqual(
        description.textContent.trim(),
        I18n.t("user_menu.reviewable.new_post_in_topic", {
          title: "This is unsafe title <a>",
        })
      );
      assert.strictEqual(
        description.querySelectorAll("img.emoji").length,
        1,
        "emojis are rendered"
      );
      assert.ok(!exists(".reviewable-description a"));
    });
  }
);
