import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import dSelect from "discourse/tests/helpers/d-select-helper";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

acceptance(
  "User - Preferences - Profile - Hide Profile Allowed",
  function (needs) {
    needs.user();
    needs.settings({ allow_users_to_hide_profile: true });

    test("user can hide profile", async function (assert) {
      await visit("/my/preferences/profile");

      assert
        .dom(".pref-hide-profile")
        .exists("checkbox to hide profile is shown");
    });
  }
);

acceptance(
  "User - Preferences - Profile - Hide Profile Not Allowed",
  function (needs) {
    needs.user();
    needs.settings({ allow_users_to_hide_profile: false });

    test("user can hide profile", async function (assert) {
      await visit("/my/preferences/profile");

      assert
        .dom(".pref-hide-profile")
        .doesNotExist("checkbox to hide profile is hidden");
    });
  }
);

acceptance("User - Preferences - Profile - Featured topic", function (needs) {
  needs.user();

  needs.settings({ allow_featured_topic_on_user_profiles: true });

  needs.pretender((server, helper) => {
    server.put("/u/eviltrout/feature-topic", () =>
      helper.response({ success: true })
    );
  });

  test("setting featured topic on profile", async function (assert) {
    await visit("/u/eviltrout/preferences/profile");

    assert
      .dom(".featured-topic-link")
      .doesNotExist("no featured topic link to present");
    assert
      .dom(".clear-feature-topic-on-profile-btn")
      .doesNotExist("clear button not present");

    await click(".feature-topic-on-profile-btn");

    assert
      .dom(".feature-topic-on-profile")
      .exists("topic picker modal is open");

    await click('input[name="choose_topic_id"]');
    await click(".save-featured-topic-on-profile");

    assert
      .dom(".featured-topic-link")
      .exists("link to featured topic is present");
    assert
      .dom(".clear-feature-topic-on-profile-btn")
      .exists("clear button is present");
  });

  test("focused item after closing feature topic modal", async function (assert) {
    await visit("/u/eviltrout/preferences/profile");
    await click(".feature-topic-on-profile-btn");
    await click(".modal-close");

    assert
      .dom(".feature-topic-on-profile-btn")
      .isFocused("it keeps focus on the feature topic button");
  });
});

acceptance(
  "User - Preferences - Profile - Featured topic with the new select controls",
  function (needs) {
    const FIELD = "[data-setting-name='user-featured-topic'] .d-select";
    let saves, featureRequests;

    needs.user();
    needs.settings({
      allow_featured_topic_on_user_profiles: true,
      enable_new_select_controls: true,
    });
    needs.hooks.beforeEach(() => {
      saves = [];
      featureRequests = [];
    });

    needs.pretender((server, helper) => {
      const topic = { id: 280, title: "Some topic", fancy_title: "Some topic" };
      server.get("/search/query", () =>
        helper.response({
          topics: [topic],
          posts: [{ id: 2800, topic_id: 280 }],
        })
      );
      server.get("/topics/lookup.json", () =>
        helper.response({ topics: [topic] })
      );
      server.put("/u/eviltrout.json", (request) => {
        saves.push(new URLSearchParams(request.requestBody));
        return helper.response({ user: {} });
      });
      server.put("/u/eviltrout/feature-topic", () => {
        featureRequests.push("feature");
        return helper.response({ success: true });
      });
      server.put("/u/eviltrout/clear-featured-topic", () => {
        featureRequests.push("clear");
        return helper.response({ success: true });
      });
    });

    test("picks the featured topic in the form and saves it with the profile", async function (assert) {
      await visit("/u/eviltrout/preferences/profile");

      assert
        .dom(".feature-topic-on-profile-btn")
        .doesNotExist("no modal to open");

      const select = dSelect(FIELD);
      await select.open();
      await select.search("some");
      await select.selectByName("Some topic");

      assert.deepEqual(featureRequests, [], "nothing is saved on pick");

      await click(".save-changes");

      assert.strictEqual(saves.length, 1);
      assert.strictEqual(saves[0].get("featured_topic_id"), "280");
      assert.deepEqual(featureRequests, [], "the profile save carries it");
    });

    test("clearing the field clears the featured topic on save", async function (assert) {
      pretender.get("/u/eviltrout.json", () => {
        const json = cloneJSON(userFixtures["/u/eviltrout.json"]);
        json.user.can_edit = true;
        json.user.featured_topic = {
          id: 280,
          title: "Some topic",
          fancy_title: "Some topic",
          slug: "some-topic",
        };
        return response(json);
      });
      await visit("/u/eviltrout/preferences/profile");

      const select = dSelect(FIELD);
      assert.dom(FIELD).hasAttribute("data-value", "280", "the topic is held");

      await select.clear();
      await click(".save-changes");

      assert.strictEqual(saves[0].get("featured_topic_id"), "");
      assert.dom(FIELD).hasAttribute("data-value", "", "and stays cleared");
      assert.deepEqual(featureRequests, [], "the profile save carries it");
    });

    test("saving an untouched field sends no featured topic", async function (assert) {
      await visit("/u/eviltrout/preferences/profile");
      await click(".save-changes");

      assert.strictEqual(saves.length, 1);
      assert.false(
        saves[0].has("featured_topic_id"),
        "the held topic is left as it is"
      );
    });
  }
);

acceptance(
  "User - Preferences - Profile - No default calendar set",
  function (needs) {
    needs.user();

    needs.pretender((server, helper) => {
      server.get("/u/eviltrout.json", () => {
        const cloned = cloneJSON(userFixtures["/u/eviltrout.json"]);
        cloned.user.can_edit = true;
        cloned.user.user_option.default_calendar = "none_selected";
        return helper.response(cloned);
      });
    });

    test("default calendar option is not visible", async function (assert) {
      await visit("/u/eviltrout/preferences/profile");

      assert
        .dom("#user-default-calendar")
        .doesNotExist("option to change default calendar is hidden");
    });
  }
);

acceptance(
  "User - Preferences - Profile - Default calendar set",
  function (needs) {
    needs.user();

    needs.pretender((server, helper) => {
      server.get("/u/eviltrout.json", () => {
        const cloned = cloneJSON(userFixtures["/u/eviltrout.json"]);
        cloned.user.can_edit = true;
        cloned.user.user_option.default_calendar = "google";
        return helper.response(cloned);
      });
    });

    test("default calendar can be changed", async function (assert) {
      await visit("/u/eviltrout/preferences/profile");

      assert
        .dom("#user-default-calendar")
        .exists("option to change default calendar");

      const calendarSelector = selectKit("#user-default-calendar");
      await calendarSelector.expand();

      for (const calendar of ["google", "outlook", "apple", "ics"]) {
        assert.true(
          calendarSelector.rowByValue(calendar).exists(),
          `${calendar} is available as a default calendar`
        );
      }
    });
  }
);
