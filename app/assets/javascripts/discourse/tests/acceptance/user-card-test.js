import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, triggerKeyEvent, visit } from "@ember/test-helpers";
import User from "discourse/models/user";
import { test } from "qunit";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import { cloneJSON } from "discourse-common/lib/object";

acceptance("User Card - Show Local Time", function (needs) {
  needs.user();
  needs.settings({ display_local_time_in_user_card: true });
  needs.pretender((server, helper) => {
    const cardResponse = cloneJSON(userFixtures["/u/charlie/card.json"]);
    delete cardResponse.user.timezone;
    server.get("/u/charlie/card.json", () => helper.response(cardResponse));
  });

  test("user card local time - does not update timezone for another user", async function (assert) {
    User.current().timezone = "Australia/Brisbane";

    await visit("/t/internationalization-localization/280");
    await click('a[data-user-card="charlie"]');

    assert.notOk(
      exists(".user-card .local-time"),
      "it does not show the local time if the user card returns a null/undefined timezone for another user"
    );
  });
});

acceptance(
  "User Card - when 'prioritize username in ux' is enabled",
  function (needs) {
    needs.user();
    needs.settings({ prioritize_username_in_ux: true });
    needs.pretender((server, helper) => {
      const cardResponse = cloneJSON(userFixtures["/u/eviltrout/card.json"]);
      server.get("/u/eviltrout/card.json", () => helper.response(cardResponse));
    });

    test("it displays the person's username followed by ther fullname", async function (assert) {
      await visit("/t/this-is-a-test-topic/9");
      await click('a[data-user-card="eviltrout"]');

      assert.equal(
        query(".user-card h1.username .name-username-wrapper").innerText,
        "eviltrout"
      );
      assert.equal(query(".user-card h2.full-name").innerText, "Robin Ward");
    });
  }
);

acceptance(
  "User Card - when 'prioritize username in ux' is disabled",
  function (needs) {
    needs.user();
    needs.settings({ prioritize_username_in_ux: false });
    needs.pretender((server, helper) => {
      const cardResponse = cloneJSON(userFixtures["/u/eviltrout/card.json"]);
      server.get("/u/eviltrout/card.json", () => helper.response(cardResponse));
    });

    test("it displays the person's fullname followed by their username", async function (assert) {
      await visit("/t/this-is-a-test-topic/9");
      await click('a[data-user-card="eviltrout"]');

      assert.equal(
        query(".user-card h1.full-name .name-username-wrapper").innerText,
        "Robin Ward"
      );
      assert.equal(query(".user-card h2.username").innerText, "eviltrout");
    });
  }
);

acceptance("User Card - User Status", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    const response = cloneJSON(userFixtures["/u/charlie/card.json"]);
    response.user.status = { description: "off to dentist" };
    server.get("/u/charlie/card.json", () => helper.response(response));
  });

  test("shows user status if enabled", async function (assert) {
    this.siteSettings.enable_user_status = true;

    await visit("/t/internationalization-localization/280");
    await click('a[data-user-card="charlie"]');

    assert.ok(exists(".user-card h3.user-status"));
  });

  test("doesn't show user status if disabled", async function (assert) {
    this.siteSettings.enable_user_status = false;

    await visit("/t/internationalization-localization/280");
    await click('a[data-user-card="charlie"]');

    assert.notOk(exists(".user-card h3.user-status"));
  });
});

acceptance("User card - Accessibility", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    const cardResponse = cloneJSON(userFixtures["/u/eviltrout/card.json"]);
    server.get("/u/eviltrout/card.json", () => helper.response(cardResponse));
  });

  test("user card focuses correctly", async function (assert) {
    await visit("/");
    const userAvatar = document.querySelector('a[data-user-card="eviltrout"]');
    userAvatar.focus();

    await triggerKeyEvent(document.activeElement, "keydown", "Enter");

    assert.ok(exists(".user-card-eviltrout"), "evil trout's user card exists");
    assert.strictEqual(
      document.activeElement,
      document.querySelector(".card-huge-avatar"),
      "first element inside user card is in focus"
    );

    await triggerKeyEvent(document.activeElement, "keydown", "Escape");
    assert.ok(
      !exists(document.querySelector("user-card.show"), "user card is hidden")
    );
    assert.strictEqual(
      document.activeElement,
      userAvatar,
      "user avatar returns to focus"
    );
  });
});
