import { visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("header-notifications-avatar-size transformer", function (needs) {
  needs.user();

  test("applying a value transformation", async function (assert) {
    withPluginApi("1.34.0", (api) => {
      api.registerValueTransformer(
        "header-notifications-avatar-size",
        () => "huge"
      );
    });

    await visit("/");

    assert
      .dom(".current-user .avatar")
      .hasAttribute("width", "144", "it transforms the avatar width");

    assert
      .dom(".current-user .avatar")
      .hasAttribute("height", "144", "it transforms the avatar height");
  });
});
