import {
  acceptance,
  exists,
  query,
} from "discourse/tests/helpers/qunit-helpers";
import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse-common/lib/object";
import userFixtures from "discourse/tests/fixtures/user-fixtures";

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

    assert.ok(
      !exists(".featured-topic-link"),
      "no featured topic link to present"
    );
    assert.ok(
      !exists(".clear-feature-topic-on-profile-btn"),
      "clear button not present"
    );

    await click(".feature-topic-on-profile-btn");

    assert.ok(
      exists(".feature-topic-on-profile"),
      "topic picker modal is open"
    );

    await click(query('input[name="choose_topic_id"]'));
    await click(".save-featured-topic-on-profile");

    assert.ok(
      exists(".featured-topic-link"),
      "link to featured topic is present"
    );
    assert.ok(
      exists(".clear-feature-topic-on-profile-btn"),
      "clear button is present"
    );
  });

  test("focused item after closing feature topic modal", async function (assert) {
    await visit("/u/eviltrout/preferences/profile");
    await click(".feature-topic-on-profile-btn");
    await click(".modal-close");

    assert.equal(
      document.activeElement,
      query(".feature-topic-on-profile-btn"),
      "it keeps focus on the feature topic button"
    );
  });
});

acceptance(
  "User - Preferences - Profile - No default calendar set",
  function (needs) {
    needs.user();

    needs.pretender((server, helper) => {
      server.get("/u/eviltrout.json", () => {
        const cloned = cloneJSON(userFixtures["/u/eviltrout.json"]);
        cloned.user.user_option.default_calendar = "none_selected";
        return helper.response(200, cloned);
      });
    });

    test("default calendar option is not visible", async function (assert) {
      await visit("/u/eviltrout/preferences/profile");

      assert.ok(
        !exists("#user-default-calendar"),
        "option to change default calendar is hidden"
      );
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
        cloned.user.user_option.default_calendar = "google";
        return helper.response(200, cloned);
      });
    });

    test("default calendar can be changed", async function (assert) {
      await visit("/u/eviltrout/preferences/profile");

      assert.ok(
        exists("#user-default-calendar"),
        "option to change default calendar"
      );
    });
  }
);
