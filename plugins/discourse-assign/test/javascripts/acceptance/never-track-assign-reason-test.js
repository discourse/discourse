import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import topicFixtures from "discourse/tests/fixtures/topic";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

acceptance(
  "Discourse Assign | Never track topics assign reason",
  function (needs) {
    needs.user({ can_send_private_messages: true });
    needs.settings({
      assign_enabled: true,
      assigns_user_url_path: "/",
    });

    needs.pretender((server, helper) => {
      server.get("/t/44.json", () => {
        let topic = cloneJSON(topicFixtures["/t/130.json"]);
        topic.details.notifications_reason_id = 3;
        return helper.response(topic);
      });
      server.get("/t/45.json", () => {
        let topic = cloneJSON(topicFixtures["/t/28830/1.json"]);
        topic["assigned_to_user"] = {
          username: "eviltrout",
          name: "Robin Ward",
          avatar_template:
            "/letter_avatar/eviltrout/{size}/3_f9720745f5ce6dfc2b5641fca999d934.png",
        };
        return helper.response(topic);
      });
      server.get("/t/46.json", () => {
        let topic = cloneJSON(topicFixtures["/t/28830/1.json"]);
        topic["assigned_to_group"] = {
          id: 47,
          name: "discourse",
        };
        return helper.response(topic);
      });
    });

    test("Show default assign reason when user tracks topics", async function (assert) {
      updateCurrentUser({ never_auto_track_topics: false });

      await visit("/t/assignment-topic/44");

      assert
        .dom(".topic-notifications-button .reason span.text")
        .hasText(
          "You will receive notifications because you are watching this topic."
        );
    });

    test("Show user assign reason when user never tracks topics", async function (assert) {
      updateCurrentUser({
        never_auto_track_topics: true,
      });

      await visit("/t/assignment-topic/45");

      assert
        .dom(".topic-notifications-button .reason span.text")
        .hasText(
          "You will see a count of new replies because this topic was assigned to you."
        );
    });
  }
);
