import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module(
  "Integration | Component | Widget | topic-participant",
  function (hooks) {
    setupRenderingTest(hooks);

    test("one post", async function (assert) {
      this.set("args", {
        username: "test",
        avatar_template: "/images/avatar.png",
        post_count: 1,
      });

      await render(
        hbs`<MountWidget @widget="topic-participant" @args={{this.args}} />`
      );

      assert.ok(exists("a.poster.trigger-user-card"));
      assert.ok(!exists("span.post-count"), "don't show count for only 1 post");
      assert.ok(!exists(".avatar-flair"), "no avatar flair");
    });

    test("many posts, a primary group with flair", async function (assert) {
      this.set("args", {
        username: "test",
        avatar_template: "/images/avatar.png",
        post_count: 2,
        primary_group_name: "devs",
        flair_name: "devs",
        flair_url: "/images/d-logo-sketch-small.png",
        flair_bg_color: "222",
        flair_group_id: "41",
      });

      await render(
        hbs`<MountWidget @widget="topic-participant" @args={{this.args}} />`
      );

      assert.ok(exists("a.poster.trigger-user-card"));
      assert.ok(exists("span.post-count"), "show count for many posts");
      assert.ok(
        exists(".group-devs a.poster"),
        "add class for the group outside the link"
      );
      assert.ok(
        exists(".avatar-flair.avatar-flair-devs"),
        "show flair with group class"
      );
    });
  }
);
