import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import { cloneJSON } from "discourse/lib/object";
import { disableClearA11yAnnouncementsInTests } from "discourse/services/a11y";
import topicFixtures from "discourse/tests/fixtures/topic";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("Topic - unread posts announcement", function (needs) {
  needs.user();

  let topicJson;

  needs.hooks.beforeEach(function () {
    disableClearA11yAnnouncementsInTests();

    topicJson = cloneJSON(topicFixtures["/t/280/1.json"]);
    topicJson.last_read_post_number = 15;
    topicJson.highest_post_number = 20;
  });

  needs.pretender((server, helper) => {
    server.get("/t/280.json", () => helper.response(topicJson));
    server.get("/t/280/:post_number.json", () => helper.response(topicJson));
  });

  test("announces the unread post count when entering a topic", async function (assert) {
    await visit("/t/internationalization-localization/280");

    assert
      .dom("#a11y-announcements-polite")
      .hasText(
        i18n("topic.unread_posts", { count: 5 }),
        "politely announces highest_post_number - last_read_post_number"
      );
  });

  test("stays silent when the topic has never been read", async function (assert) {
    topicJson.last_read_post_number = null;

    await visit("/t/internationalization-localization/280");

    assert
      .dom("#a11y-announcements-polite")
      .hasText("", "no announcement without a last read post number");
  });

  test("stays silent when the topic is fully read", async function (assert) {
    topicJson.last_read_post_number = 20;

    await visit("/t/internationalization-localization/280");

    assert
      .dom("#a11y-announcements-polite")
      .hasText("", "no announcement when there are no unread posts");
  });

  test("does not repeat while moving between posts of the same topic", async function (assert) {
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
    const message = i18n("topic.unread_posts", { count: 5 });

    await visit("/t/internationalization-localization/280");
    await visit("/t/internationalization-localization/280/2");

    assert.strictEqual(
      announce.withArgs(message).callCount,
      1,
      "announced only once for the same topic entry"
    );
  });

  test("announces again after leaving and re-entering the topic", async function (assert) {
    const announce = sinon.spy(this.owner.lookup("service:a11y"), "announce");
    const message = i18n("topic.unread_posts", { count: 5 });

    await visit("/t/internationalization-localization/280");
    await visit("/latest");
    await visit("/t/internationalization-localization/280");

    assert.strictEqual(
      announce.withArgs(message).callCount,
      2,
      "each fresh topic entry announces"
    );
  });
});
