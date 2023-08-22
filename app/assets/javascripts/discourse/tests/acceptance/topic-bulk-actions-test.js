import {
  acceptance,
  count,
  queryAll,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import { click, triggerEvent, visit } from "@ember/test-helpers";
import { test } from "qunit";
import I18n from "I18n";

acceptance("Topic - Bulk Actions", function (needs) {
  needs.user();
  needs.settings({ tagging_enabled: true });
  needs.pretender((server, helper) => {
    server.put("/topics/bulk", () => {
      return helper.response({
        topic_ids: [],
      });
    });
  });

  test("bulk select - modal", async function (assert) {
    updateCurrentUser({
      moderator: true,
      user_option: { enable_defer: true },
    });
    await visit("/latest");
    await click("button.bulk-select");

    await click(queryAll("input.bulk-select")[0]);
    await click(queryAll("input.bulk-select")[1]);

    await click(".bulk-select-actions");

    assert
      .dom("#discourse-modal-title")
      .hasText(I18n.t("topics.bulk.actions"), "it opens bulk-select modal");

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.change_category"),
        "it shows an option to change category"
      );

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.close_topics"),
        "it shows an option to close topics"
      );

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.archive_topics"),
        "it shows an option to archive topics"
      );

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.notification_level"),
        "it shows an option to update notification level"
      );

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.defer"),
        "it shows an option to reset read"
      );

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.unlist_topics"),
        "it shows an option to unlist topics"
      );

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.reset_bump_dates"),
        "it shows an option to reset bump dates"
      );

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.change_tags"),
        "it shows an option to replace tags"
      );

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.append_tags"),
        "it shows an option to append tags"
      );

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.remove_tags"),
        "it shows an option to remove all tags"
      );

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.delete"),
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

    assert
      .dom(".topic-bulk-actions-modal")
      .doesNotExist("it closes the bulk select modal");
  });

  test("bulk select - Shift click selection", async function (assert) {
    updateCurrentUser({ moderator: true });
    await visit("/latest");
    await click("button.bulk-select");

    await click(queryAll("input.bulk-select")[0]);
    await triggerEvent(queryAll("input.bulk-select")[3], "click", {
      shiftKey: true,
    });
    assert.strictEqual(
      count("input.bulk-select:checked"),
      4,
      "Shift click selects a range"
    );

    await click("button.bulk-clear-all");

    await click(queryAll("input.bulk-select")[5]);
    await triggerEvent(queryAll("input.bulk-select")[1], "click", {
      shiftKey: true,
    });
    assert.strictEqual(
      count("input.bulk-select:checked"),
      5,
      "Bottom-up Shift click range selection works"
    );
  });

  test("bulk select is not available for users who are not staff or TL4", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, trust_level: 1 });
    await visit("/latest");
    assert
      .dom(".button.bulk-select")
      .doesNotExist("non-staff and < TL4 users cannot bulk select");
  });

  test("TL4 users can bulk select", async function (assert) {
    updateCurrentUser({
      moderator: false,
      admin: false,
      trust_level: 4,
      user_option: { enable_defer: false },
    });

    await visit("/latest");
    await click("button.bulk-select");

    await click(queryAll("input.bulk-select")[0]);
    await click(queryAll("input.bulk-select")[1]);
    await click(".bulk-select-actions");

    assert
      .dom("#discourse-modal-title")
      .hasText(I18n.t("topics.bulk.actions"), "it opens bulk-select modal");

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.change_category"),
        "it shows an option to change category"
      );

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.close_topics"),
        "it shows an option to close topics"
      );

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.archive_topics"),
        "it shows an option to archive topics"
      );

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.notification_level"),
        "it shows an option to update notification level"
      );

    assert
      .dom(".bulk-buttons")
      .doesNotIncludeText(
        I18n.t("topics.bulk.defer"),
        "it does not show an option to reset read"
      );

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.unlist_topics"),
        "it shows an option to unlist topics"
      );

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.reset_bump_dates"),
        "it shows an option to reset bump dates"
      );

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.change_tags"),
        "it shows an option to replace tags"
      );

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.append_tags"),
        "it shows an option to append tags"
      );

    assert
      .dom(".bulk-buttons")
      .includesText(
        I18n.t("topics.bulk.remove_tags"),
        "it shows an option to remove all tags"
      );

    assert
      .dom(".bulk-buttons")
      .doesNotIncludeText(
        I18n.t("topics.bulk.delete"),
        "it does not show an option to delete topics"
      );
  });
});
