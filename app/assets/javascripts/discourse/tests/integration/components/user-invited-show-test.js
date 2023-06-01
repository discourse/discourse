import { cloneJSON } from "discourse-common/lib/object";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import {
  acceptance,
  count,
  exists,
  loggedInUser,
  publishToMessageBus,
  query,
  queryAll,
  visible,
} from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import I18n from "I18n";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import { test } from "qunit";

acceptance("User invites", function (needs) {
  needs.user();

  test("hides delete button based on can_delete_invite", async function (assert) {
    await visit("/u/eviltrout/invited");

    assert.dom("table.user-invite-list tbody tr").exists({ count: 2 });
    assert
      .dom("table.user-invite-list tbody tr:nth-child(1) button.cancel")
      .exists();
    assert
      .dom("table.user-invite-list tbody tr:nth-child(2) button.cancel")
      .doesNotExist();
  });
});
