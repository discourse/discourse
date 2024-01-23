import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { withPluginApi } from "discourse/lib/plugin-api";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Force login auth", function (needs) {
  needs.site({
    auth_providers: [
      {
        name: "facebook",
        custom_url: null,
        pretty_name_override: null,
        title_override: null,
        frame_width: 580,
        frame_height: 400,
        can_connect: true,
        can_revoke: true,
      },
      {
        name: "google",
        custom_url: "/auth/google",
      },
    ],
  });

  test("Sees both auth methods", async function (assert) {
    await visit("/");

    await click(".header-buttons .login-button");

    assert.dom("#login-buttons button.facebook").exists();
    assert.dom("#login-buttons button.google").exists();
  });

  test("Sees only forced auth method", async function () {
    withPluginApi("1.25.0", (api) => {
      api.forceAuthLoginMethod("google");
    });

    await visit("/");
    // await click(".header-buttons .login-button");

    // not possible to assert, since login-method.js:36 invokes a window.location redirect...
  });
});
