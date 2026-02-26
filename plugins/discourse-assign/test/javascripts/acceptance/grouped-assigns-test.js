import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import AssignedTopics from "../fixtures/assigned-topics-fixtures";

function topicWithDuplicateAssignee() {
  const topics = cloneJSON(
    AssignedTopics["/topics/messages-assigned/eviltrout.json"]
  );
  const topic = topics.topic_list.topics[0];

  topic.assigned_to_user = {
    id: 19,
    username: "eviltrout",
    name: "Robin Ward",
    avatar_template: "/letter_avatar_proxy/v4/letter/e/ed8c4c/{size}.png",
  };
  topic.indirectly_assigned_to = {
    101: {
      assigned_to: {
        id: 19,
        username: "eviltrout",
        name: "Robin Ward",
        avatar_template: "/letter_avatar_proxy/v4/letter/e/ed8c4c/{size}.png",
      },
      post_number: 2,
    },
    102: {
      assigned_to: {
        id: 19,
        username: "eviltrout",
        name: "Robin Ward",
        avatar_template: "/letter_avatar_proxy/v4/letter/e/ed8c4c/{size}.png",
      },
      post_number: 3,
    },
  };

  topics.topic_list.topics = [topic];
  return topics;
}

acceptance(
  "Discourse Assign | Grouped assigns in topic list",
  function (needs) {
    needs.user();
    needs.settings({
      assign_enabled: true,
      assigns_user_url_path: "/u/{username}/activity/assigned",
      tagging_enabled: true,
    });
    needs.pretender((server, helper) => {
      server.get("/topics/messages-assigned/eviltrout.json", () =>
        helper.response(topicWithDuplicateAssignee())
      );
    });

    test("groups duplicate assignees with count badge", async function (assert) {
      updateCurrentUser({ can_assign: true });
      await visit("/u/eviltrout/activity/assigned");

      assert
        .dom(".grouped-assign-tag")
        .exists("shows grouped assign tag for duplicate assignees");
      assert
        .dom(".grouped-assign-tag .assign-count")
        .hasText("×3", "shows correct count for 3 assignments to same user");
    });

    test("clicking grouped tag opens dropdown menu", async function (assert) {
      updateCurrentUser({ can_assign: true });
      await visit("/u/eviltrout/activity/assigned");

      await click(".grouped-assign-tag");

      assert
        .dom(".grouped-assigns-dropdown-content")
        .exists("dropdown menu is visible");
      assert
        .dom(".grouped-assigns-dropdown-content .assignment-link")
        .exists({ count: 3 }, "shows all 3 assignments in dropdown");
    });

    test("dropdown shows topic and post assignments", async function (assert) {
      updateCurrentUser({ can_assign: true });
      await visit("/u/eviltrout/activity/assigned");

      await click(".grouped-assign-tag");

      assert
        .dom(".grouped-assigns-dropdown-content")
        .includesText("Topic", "shows topic-level assignment");
      assert
        .dom(".grouped-assigns-dropdown-content")
        .includesText("Post #2", "shows post #2 assignment");
      assert
        .dom(".grouped-assigns-dropdown-content")
        .includesText("Post #3", "shows post #3 assignment");
    });

    test("grouped tag has accessibility attributes", async function (assert) {
      updateCurrentUser({ can_assign: true });
      await visit("/u/eviltrout/activity/assigned");

      assert
        .dom(".grouped-assign-tag")
        .hasAttribute(
          "aria-haspopup",
          "true",
          "has aria-haspopup for screen readers"
        );
      assert
        .dom(".grouped-assign-tag")
        .hasAttribute("type", "button", "is a button element");
    });
  }
);

acceptance(
  "Discourse Assign | Single assignee shows regular tag",
  function (needs) {
    needs.user();
    needs.settings({
      assign_enabled: true,
      assigns_user_url_path: "/u/{username}/activity/assigned",
      tagging_enabled: true,
    });
    needs.pretender((server, helper) => {
      server.get("/topics/messages-assigned/eviltrout.json", () =>
        helper.response(
          cloneJSON(AssignedTopics["/topics/messages-assigned/eviltrout.json"])
        )
      );
    });

    test("single assignee shows regular link, not grouped button", async function (assert) {
      updateCurrentUser({ can_assign: true });
      await visit("/u/eviltrout/activity/assigned");

      assert
        .dom(".grouped-assign-tag")
        .doesNotExist("no grouped tag for single assignment");
      assert
        .dom(".assigned-to.discourse-tag")
        .exists("shows regular assign tag");
    });
  }
);
