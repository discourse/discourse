import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  count,
  discourseModule,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import EmberObject from "@ember/object";
import hbs from "htmlbars-inline-precompile";
import pretender from "discourse/tests/helpers/create-pretender";
import { settled } from "@ember/test-helpers";

discourseModule(
  "Integration | Component | Widget | default-notification-item",
  function (hooks) {
    setupRenderingTest(hooks);

    componentTest("sets notification as read on middle click", {
      template: hbs`{{mount-widget widget="default-notification-item" args=args}}`,
      beforeEach() {
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
      },
      async test(assert) {
        let requests = 0;
        pretender.put("/notifications/mark-read", (request) => {
          ++requests;

          assert.equal(
            request.requestBody,
            `id=${this.args.id}`,
            "it sets correct request parameters"
          );

          return [
            200,
            { "Content-Type": "application/json" },
            { success: true },
          ];
        });

        assert.ok(!exists("li.read"));

        $(document).trigger(
          $.Event("mouseup", {
            target: query("li"),
            button: 1,
            which: 2,
          })
        );
        await settled();

        assert.equal(count("li.read"), 1);
        assert.equal(requests, 1);
      },
    });
  }
);
