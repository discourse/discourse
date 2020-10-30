import { exists } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import User from "discourse/models/user";
import { click } from "@ember/test-helpers";

acceptance("User Card - Show Local Time", function (needs) {
  needs.user();
  needs.settings({ display_local_time_in_user_card: true });
  needs.pretender((server, helper) => {
    let cardResponse = Object.assign({}, userFixtures["/u/charlie/card.json"]);
    delete cardResponse.user.timezone;
    server.get("/u/charlie/card.json", () => helper.response(cardResponse));
  });

  test("user card local time - does not update timezone for another user", async (assert) => {
    User.current().changeTimezone("Australia/Brisbane");

    await visit("/t/internationalization-localization/280");
    await click("a[data-user-card=charlie]:first");

    assert.not(
      exists(".user-card .local-time"),
      "it does not show the local time if the user card returns a null/undefined timezone for another user"
    );
  });
});
