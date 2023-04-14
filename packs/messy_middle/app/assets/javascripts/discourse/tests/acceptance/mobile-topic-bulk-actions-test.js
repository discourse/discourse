import {
  acceptance,
  invisible,
  query,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import I18n from "I18n";

acceptance("Topic - Bulk Actions - Mobile", function (needs) {
  needs.user();
  needs.mobileView();

  needs.settings({ tagging_enabled: true });
  needs.pretender((server, helper) => {
    server.put("/topics/bulk", () => {
      return helper.response({
        topic_ids: [],
      });
    });
  });

  test("bulk select - modal", async function (assert) {
    updateCurrentUser({ moderator: true, user_option: { enable_defer: true } });
    await visit("/latest");
    await click("button.bulk-select");

    await click(queryAll("input.bulk-select")[0]);
    await click(queryAll("input.bulk-select")[1]);

    await click(".bulk-select-actions");

    assert.ok(
      query("#discourse-modal-title").innerHTML.includes(
        I18n.t("topics.bulk.actions")
      ),
      "it opens bulk-select modal"
    );

    assert.ok(
      query(".bulk-buttons").innerHTML.includes(
        I18n.t("topics.bulk.change_category")
      ),
      "it shows an option to change category"
    );

    assert.ok(
      query(".bulk-buttons").innerHTML.includes(
        I18n.t("topics.bulk.close_topics")
      ),
      "it shows an option to close topics"
    );

    assert.ok(
      query(".bulk-buttons").innerHTML.includes(
        I18n.t("topics.bulk.archive_topics")
      ),
      "it shows an option to archive topics"
    );

    assert.ok(
      query(".bulk-buttons").innerHTML.includes(
        I18n.t("topics.bulk.notification_level")
      ),
      "it shows an option to update notification level"
    );

    assert.ok(
      query(".bulk-buttons").innerHTML.includes(I18n.t("topics.bulk.defer")),
      "it shows an option to reset read"
    );

    assert.ok(
      query(".bulk-buttons").innerHTML.includes(
        I18n.t("topics.bulk.unlist_topics")
      ),
      "it shows an option to unlist topics"
    );

    assert.ok(
      query(".bulk-buttons").innerHTML.includes(
        I18n.t("topics.bulk.reset_bump_dates")
      ),
      "it shows an option to reset bump dates"
    );

    assert.ok(
      query(".bulk-buttons").innerHTML.includes(
        I18n.t("topics.bulk.change_tags")
      ),
      "it shows an option to replace tags"
    );

    assert.ok(
      query(".bulk-buttons").innerHTML.includes(
        I18n.t("topics.bulk.append_tags")
      ),
      "it shows an option to append tags"
    );

    assert.ok(
      query(".bulk-buttons").innerHTML.includes(
        I18n.t("topics.bulk.remove_tags")
      ),
      "it shows an option to remove all tags"
    );

    assert.ok(
      query(".bulk-buttons").innerHTML.includes(I18n.t("topics.bulk.delete")),
      "it shows an option to delete topics"
    );
  });

  test("bulk select - delete topics", async function (assert) {
    updateCurrentUser({ moderator: true });
    await visit("/latest");
    await click("button.bulk-select");

    await click(queryAll("input.bulk-select")[0]);
    await click(queryAll("input.bulk-select")[1]);

    await click(".bulk-select-actions");
    await click(".modal-body .delete-topics");

    assert.ok(
      invisible(".topic-bulk-actions-modal"),
      "it closes the bulk select modal"
    );
  });
});
