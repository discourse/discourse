import { currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import {
  acceptance,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { i18n } from "discourse-i18n";
import AssignedTopics from "../fixtures/assigned-topics-fixtures";

acceptance("Discourse Assign | User Private Messages", function (needs) {
  needs.user({
    can_assign: true,
  });

  needs.settings({ assign_enabled: true, assigns_user_url_path: "/" });

  needs.pretender((server, helper) => {
    const assignments = cloneJSON(
      AssignedTopics["/topics/messages-assigned/eviltrout.json"]
    );

    server.get("/topics/private-messages-assigned/eviltrout.json", () =>
      helper.response(assignments)
    );
  });

  test("viewing assigned messages", async function (assert) {
    updateCurrentUser({ redesigned_user_page_nav_enabled: true });

    await visit("/u/eviltrout/messages");

    const messagesDropdown = selectKit(".user-nav-messages-dropdown");

    await messagesDropdown.expand();
    await messagesDropdown.selectRowByName(i18n("discourse_assign.assigned"));

    assert.strictEqual(
      currentURL(),
      "/u/eviltrout/messages/assigned",
      "transitioned to the assigned page"
    );

    assert.strictEqual(
      messagesDropdown.header().name(),
      i18n("discourse_assign.assigned"),
      "assigned messages is selected in the dropdown"
    );
  });
});
