import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("User invites", function (needs) {
  needs.user();

  test("hides delete button based on can_delete_invite", async function (assert) {
    await visit("/u/eviltrout/invited");

    assert.dom("table.user-invite-list tbody tr").exists({ count: 3 });

    assert
      .dom(
        "table.user-invite-list tbody tr:nth-child(1) .d-icon-ellipsis-vertical"
      )
      .exists();

    await click(
      "table.user-invite-list tbody tr:nth-child(1) .d-icon-ellipsis-vertical"
    );
    assert.dom(".btn-danger").exists();

    assert
      .dom(
        "table.user-invite-list tbody tr:nth-child(2) .d-icon-ellipsis-vertical"
      )
      .doesNotExist();
  });
});
