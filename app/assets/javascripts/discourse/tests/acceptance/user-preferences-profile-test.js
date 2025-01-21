import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { cloneJSON } from "discourse/lib/object";
import userFixtures from "discourse/tests/fixtures/user-fixtures";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

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
    });
  }
);
