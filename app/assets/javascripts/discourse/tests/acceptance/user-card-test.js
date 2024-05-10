import { getOwner } from "@ember/owner";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { cloneJSON } from "discourse-common/lib/object";
import I18n from "discourse-i18n";

acceptance("User Card - Show Local Time", function (needs) {
  needs.user();
  needs.settings({ display_local_time_in_user_card: true });

  test("user card local time - does not update timezone for another user", async function (assert) {
    const currentUser = getOwner(this).lookup("service:current-user");
    currentUser.user_option.timezone = "Australia/Brisbane";

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

    test("it displays the person's username followed by their fullname", async function (assert) {
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

acceptance("User Card - Hidden Profile", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/u/eviltrout/card.json", () =>
      helper.response({
        user: {
          id: 6,
          username: "eviltrout",
          name: null,
          avatar_template: "/letter_avatar_proxy/v4/letter/f/8edcca/{size}.png",
          profile_hidden: true,
          title: null,
          primary_group_name: null,
        },
      })
    );
  });

  test("it shows less information", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");
    await click('a[data-user-card="eviltrout"]');

    assert.equal(
      query(".user-card .name-username-wrapper").innerText,
      "eviltrout"
    );
    assert.equal(
      query(".user-card .profile-hidden").innerText,
      I18n.t("user.profile_hidden")
    );
  });
});

acceptance("User Card - Inactive user", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.get("/u/eviltrout/card.json", () =>
      helper.response({
        user: {
          id: 6,
          username: "eviltrout",
          name: null,
          avatar_template: "/letter_avatar_proxy/v4/letter/f/8edcca/{size}.png",
          inactive: true,
        },
      })
    );
  });

  test("it shows less information", async function (assert) {
    await visit("/t/this-is-a-test-topic/9");
    await click('a[data-user-card="eviltrout"]');

    assert.equal(
      query(".user-card .name-username-wrapper").innerText,
      "eviltrout"
    );

    assert.equal(
      query(".user-card .inactive-user").innerText,
      I18n.t("user.inactive_user")
    );
  });
});
