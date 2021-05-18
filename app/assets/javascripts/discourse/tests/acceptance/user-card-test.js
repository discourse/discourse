import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import User from "discourse/models/user";
import { test } from "qunit";
import userFixtures from "discourse/tests/fixtures/user-fixtures";

acceptance("User Card - Show Local Time", function (needs) {
  needs.user();
  needs.settings({ display_local_time_in_user_card: true });
  needs.pretender((server, helper) => {
    let cardResponse = Object.assign({}, userFixtures["/u/charlie/card.json"]);
    delete cardResponse.user.timezone;
    server.get("/u/charlie/card.json", () => helper.response(cardResponse));
  });

  test("user card local time - does not update timezone for another user", async function (assert) {
    User.current().changeTimezone("Australia/Brisbane");

    await visit("/t/internationalization-localization/280");
    await click('a[data-user-card="charlie"]');

    assert.not(
      exists(".user-card .local-time"),
      "it does not show the local time if the user card returns a null/undefined timezone for another user"
    );
  });
});
