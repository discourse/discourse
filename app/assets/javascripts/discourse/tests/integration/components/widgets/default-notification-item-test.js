import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render, triggerEvent } from "@ember/test-helpers";
import { count, exists } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import EmberObject from "@ember/object";

module(
  "Integration | Component | Widget | default-notification-item",
  function (hooks) {
    setupRenderingTest(hooks);

    test("sets notification as read on middle click", async function (assert) {
      this.set(
        "args",
        EmberObject.create({
          id: 3,
          user_id: 1,
          notification_type: 6,
          read: false,
          created_at: "2020-01-01T12:00:00.000Z",
          post_number: 1,
          topic_id: 10,
          fancy_title: "Greetings!",
          slug: "greetings",
          data: {
            topic_title: "Greetings!",
            original_post_id: 14,
            original_post_type: 1,
            original_username: "discobot",
            revision_number: null,
            display_username: "discobot",
          },
        })
      );

      await render(
        hbs`<MountWidget @widget="default-notification-item" @args={{this.args}} />`
      );

      let requests = 0;
      pretender.put("/notifications/mark-read", (request) => {
        ++requests;

        assert.strictEqual(
          request.requestBody,
          `id=${this.args.id}`,
          "it sets correct request parameters"
        );

        return response({ success: true });
      });

      assert.ok(!exists("li.read"));

      await triggerEvent("li", "mouseup", { button: 1, which: 2 });
      assert.strictEqual(count("li.read"), 1);
      assert.strictEqual(requests, 1);
    });
  }
);
