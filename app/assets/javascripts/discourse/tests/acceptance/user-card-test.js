import { getOwner } from "@ember/owner";
import { click, currentURL, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

acceptance("User Card", function (needs) {
  needs.user();

  test("opens and closes properly", async function (assert) {
    await visit("/t/internationalization-localization/280");
    await click(".topic-map__users-trigger");
    await click('a[data-user-card="charlie"]');

    assert.dom(".user-card .card-content").exists();

    await click(".card-huge-avatar");

    assert.strictEqual(currentURL(), "/u/charlie/summary");
    assert.dom(".user-card").doesNotExist();
    assert.dom(".card-content").doesNotExist();
  });
});

acceptance("User Card - Show Local Time", function (needs) {
  needs.user();
  needs.settings({ display_local_time_in_user_card: true });

  test("user card local time - does not update timezone for another user", async function (assert) {
    const currentUser = getOwner(this).lookup("service:current-user");
    currentUser.user_option.timezone = "Australia/Brisbane";

    await visit("/t/internationalization-localization/280");
    await click(".topic-map__users-trigger");
    await click('a[data-user-card="charlie"]');

    assert
      .dom(".user-card .local-time")
      .doesNotExist(
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

      assert
        .dom(".user-card .username .name-username-wrapper")
        .hasText("eviltrout");
      assert.dom(".user-card .full-name").hasText("Robin Ward");
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

      assert
        .dom(".user-card .full-name .name-username-wrapper")
        .hasText("Robin Ward");
      assert.dom(".user-card .username").hasText("eviltrout");
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

    await click(".topic-map__users-trigger");
    await click('a[data-user-card="charlie"]');

    assert.dom(".user-card .user-status").exists();
  });

  test("doesn't show user status if disabled", async function (assert) {
    this.siteSettings.enable_user_status = false;

    await visit("/t/internationalization-localization/280");

    await click(".topic-map__users-trigger");
    await click('a[data-user-card="charlie"]');

    assert.dom(".user-card .user-status").doesNotExist();
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

    assert.dom(".user-card .name-username-wrapper").hasText("eviltrout");
    assert
      .dom(".user-card .profile-hidden")
      .hasText(i18n("user.profile_hidden"));
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

    assert.dom(".user-card .name-username-wrapper").hasText("eviltrout");
    assert.dom(".user-card .inactive-user").hasText(i18n("user.inactive_user"));
  });
});
