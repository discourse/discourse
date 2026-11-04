import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import formKit from "discourse/tests/helpers/form-kit-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import topicWithAssignedPosts from "../fixtures/topic-with-assigned-posts.js";

acceptance("Multiple topic assignments", function (needs) {
  needs.user({ can_assign: true });
  needs.settings({
    assign_enabled: true,
    assign_allow_multiple_topic_assignees: true,
  });
  let assignments;
  let removed;
  let saved;
  needs.hooks.beforeEach(function () {
    removed = [];
    saved = null;
    assignments = [
      {
        id: 101,
        target_id: 44,
        target_type: "Topic",
        assigned_to_type: "User",
        assigned_to: {
          id: 1,
          username: "martin",
          avatar_template: "/letter_avatar_proxy/v4/letter/m/87869e/{size}.png",
        },
        note: "Review the character references",
      },
      {
        id: 102,
        target_id: 44,
        target_type: "Topic",
        assigned_to_type: "User",
        assigned_to: {
          id: 2,
          username: "sam",
          avatar_template: "/letter_avatar_proxy/v4/letter/s/87869e/{size}.png",
        },
        note: "Check the publication details",
      },
    ];
  });
  needs.pretender((server, helper) => {
    server.get("/assign/suggestions", () =>
      helper.response({ suggestions: [], groups: [] })
    );
    server.get("/t/44.json", () =>
      helper.response({
        ...topicWithAssignedPosts(),
        topic_assignments: assignments,
      })
    );
    server.get("/assign/topics/:topic_id/assignments", () =>
      helper.response({
        topic_assignments: assignments,
        version: "version",
        max_assignments: 20,
        active_post_assignments: 2,
        can_add_multiple: true,
      })
    );
    server.put("/assign/topics/:topic_id/assignments", (request) => {
      saved = JSON.parse(request.requestBody);
      assignments = saved.assignments.map((entry) => ({
        ...assignments.find((assignment) => assignment.id === entry.id),
        note: entry.note,
      }));
      return helper.response({
        topic_assignments: assignments,
        version: "next-version",
      });
    });
    server.delete("/assign/assignments/:id", (request) => {
      removed.push(Number(request.params.id));
      assignments = assignments.filter(
        (assignment) => assignment.id !== Number(request.params.id)
      );
      return helper.response(204);
    });
  });

  test("shows each OP note and removes only the selected direct assignment from the footer", async function (assert) {
    await visit("/t/assignment-topic/44");
    assert
      .dom("#post_1 .assigned-to__assignee")
      .exists({ count: 2 }, "both direct assignees are visible");
    assert
      .dom("#post_1 .assigned-to__note")
      .exists({ count: 2 }, "each note is displayed separately");
    assert
      .dom("#topic-footer-dropdown-reassign .assignment-avatars .avatar")
      .exists({ count: 2 }, "the footer stacks the direct assignees");
    await click("#topic-footer-dropdown-reassign .btn");
    assert
      .dom("li[data-value='unassign-assignment-101']")
      .includesText(
        "Unassign @martin from topic",
        "removal identifies the assignee and scope"
      );
    await click("li[data-value='unassign-assignment-101']");
    assert.deepEqual(
      removed,
      [101],
      "the request removes an assignment rather than clearing the topic"
    );
    assert
      .dom("#post_1 .assigned-to__assignee")
      .hasText("@sam", "the other assignee remains");
    assert
      .dom("#post_1 .assigned-to__note")
      .hasText("Check the publication details", "their note remains");
  });

  test("loads the collection modal and saves an edited note atomically", async function (assert) {
    await visit("/t/assignment-topic/44");
    await click("#topic-footer-dropdown-reassign .btn");
    await click("li[data-value='reassign']");
    assert
      .dom(".d-modal .topic-assignments-editor__row")
      .exists({ count: 2 }, "the existing modal shows one row per assignment");
    await click(
      ".topic-assignments-editor__row:first-child .topic-assignments-editor__note-action"
    );
    await formKit().field("assignments.0.note").fillIn("Updated reading notes");
    await click(".d-modal__footer .btn-primary");
    assert.strictEqual(
      saved.expected_version,
      "version",
      "the save includes the editor version"
    );
    assert.strictEqual(
      saved.assignments.length,
      2,
      "one request submits the complete set"
    );
    assert.strictEqual(
      saved.assignments[0].note,
      "Updated reading notes",
      "the note belongs to its assignee"
    );
    assert
      .dom(".d-modal")
      .doesNotExist("the modal closes after the save succeeds");
    assert
      .dom("#post_1 .assigned-to__note")
      .includesText(
        "Updated reading notes",
        "the OP reflects the saved assignments"
      );
  });
});
