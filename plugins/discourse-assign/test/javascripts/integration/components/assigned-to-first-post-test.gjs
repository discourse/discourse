import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import AssignedToFirstPost from "discourse/plugins/discourse-assign/discourse/components/assigned-to-first-post";

module("Integration | Component | AssignedToFirstPost", function (hooks) {
  setupRenderingTest(hooks);

  test("renders single and multiple assignees with optional escaped notes", async function (assert) {
    this.siteSettings.assign_allow_multiple_topic_assignees = true;
    for (const count of [1, 3]) {
      for (const withNotes of [false, true]) {
        const note = "Review <img src=x onerror=alert(1)> references";
        const post = {
          topic: {
            topic_assignments: ["martin", "sam", "alex"]
              .slice(0, count)
              .map((username, index) => ({
                id: index + 1,
                assigned_to_type: "User",
                assigned_to: { username },
                note: withNotes ? note : null,
              })),
          },
        };
        await render(
          <template><AssignedToFirstPost @post={{post}} /></template>
        );
        assert
          .dom(".assigned-to__assignee")
          .exists({ count }, `${count} assignees are visible`);
        if (withNotes) {
          assert
            .dom(".assigned-to__note")
            .exists({ count }, "each assignee's note is visible");
          assert
            .dom(".assigned-to__note")
            .hasText(note, "notes render as plain text");
          assert
            .dom(".assigned-to__note img")
            .doesNotExist("notes cannot inject markup");
        } else {
          assert
            .dom(".assigned-to__note")
            .doesNotExist("empty notes add no extra rows");
        }
      }
    }
  });
});
