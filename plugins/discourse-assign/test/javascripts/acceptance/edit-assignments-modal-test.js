import { click, settled, visit } from "@ember/test-helpers";
import { test } from "qunit";
import {
  acceptance,
  publishToMessageBus,
} from "discourse/tests/helpers/qunit-helpers";
import topicWithAssignedPosts from "../fixtures/topic-with-assigned-posts";

const topic = topicWithAssignedPosts();
const firstReply = topic.post_stream.posts[1];
const secondReply = topic.post_stream.posts[2];
const new_assignee_1 = "user_1";
const new_assignee_2 = "user_2";

["enabled", "disabled"].forEach((postStreamMode) => {
  acceptance(
    `Discourse Assign | Edit assignments modal (glimmer_post_stream_mode = ${postStreamMode})`,
    function (needs) {
      needs.user({ can_assign: true });
      needs.settings({
        assign_enabled: true,
        glimmer_post_stream_mode: postStreamMode,
      });

      needs.pretender((server, helper) => {
        server.get("/t/44.json", () => helper.response(topic));
        server.put("/assign/assign", () => {
          return helper.response({ success: true });
        });

        const suggestions = [
          { username: new_assignee_1 },
          { username: new_assignee_2 },
        ];
        server.get("/assign/suggestions", () =>
          helper.response({
            assign_allowed_for_groups: [],
            suggestions,
          })
        );
        server.get("/u/search/users", () =>
          helper.response({
            users: suggestions,
          })
        );
      });

      test("reassigning topic", async function (assert) {
        await visit("/t/assignment-topic/44");
        await openModal();
        await selectAssignee(new_assignee_1);

        await submitModal();
        await receiveAssignedMessage(topic, new_assignee_1);

        assert
          .dom(".post-stream article#post_1 .assigned-to .assigned-to--user a")
          .hasText(new_assignee_1, "The topic is assigned to a new assignee");
      });

      test("reassigning posts", async function (assert) {
        await visit("/t/assignment-topic/44");
        await openModal();

        await selectPost(1);
        await expandAssigneeChooser();
        await selectAssignee(new_assignee_1);

        await selectPost(2);
        await expandAssigneeChooser();
        await selectAssignee(new_assignee_2);

        await submitModal();
        await receiveAssignedMessage(firstReply, new_assignee_1);
        await receiveAssignedMessage(secondReply, new_assignee_2);

        assert
          .dom(".post-stream article#post_2 .assigned-to .assigned-to-username")
          .hasText(
            new_assignee_1,
            "The first reply is assigned to a new assignee"
          );

        assert
          .dom(".post-stream article#post_3 .assigned-to .assigned-to-username")
          .hasText(
            new_assignee_2,
            "The second reply is assigned to a new assignee"
          );
      });

      test("reassigning topic and posts in one go", async function (assert) {
        await visit("/t/assignment-topic/44");
        await openModal();
        await selectAssignee(new_assignee_1);

        await selectPost(1);
        await expandAssigneeChooser();
        await selectAssignee(new_assignee_2);

        await selectPost(2);
        await expandAssigneeChooser();
        await selectAssignee(new_assignee_2);

        await submitModal();
        await receiveAssignedMessage(topic, new_assignee_1);
        await receiveAssignedMessage(firstReply, new_assignee_2);
        await receiveAssignedMessage(secondReply, new_assignee_2);

        assert
          .dom(".post-stream article#post_1 .assigned-to .assigned-to--user a")
          .hasText(new_assignee_1, "The topic is assigned to a new assignee");

        assert
          .dom(".post-stream article#post_2 .assigned-to .assigned-to-username")
          .hasText(
            new_assignee_2,
            "The first reply is assigned to a new assignee"
          );

        assert
          .dom(".post-stream article#post_3 .assigned-to .assigned-to-username")
          .hasText(
            new_assignee_2,
            "The second reply is assigned to a new assignee"
          );
      });

      async function expandAssigneeChooser() {
        await click(
          ".modal-container #assignee-chooser-header .select-kit-header-wrapper"
        );
      }

      async function openModal() {
        await click("#topic-footer-dropdown-reassign .btn");
        await click(`li[data-value='reassign']`);
      }

      // todo remove this function and all calls to it after we start updating UI right away
      // (there is no need to wait for a message bus message in the browser of a user
      // who did reassignment, but we do that at the moment)
      async function receiveAssignedMessage(target, newAssignee) {
        const targetIsAPost = !!target.topic_id;

        let topicId, postId;
        if (targetIsAPost) {
          topicId = target.topic_id;
          postId = target.id;
        } else {
          topicId = target.id;
          postId = false;
        }

        await publishToMessageBus("/staff/topic-assignment", {
          type: "assigned",
          topic_id: topicId,
          post_id: postId,
          assigned_type: "User",
          assigned_to: {
            username: newAssignee,
          },
        });
        await settled();
      }

      async function selectPost(number) {
        await click(".target .single-select .select-kit-header-wrapper");
        await click(`li[title='Post #${number}']`);
      }

      async function selectAssignee(username) {
        await click(`.email-group-user-chooser-row[data-value='${username}']`);
      }

      async function submitModal() {
        await click(".d-modal__footer .btn-primary");
      }
    }
  );
});
