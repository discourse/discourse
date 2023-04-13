import { test } from "qunit";
import { click, fillIn, visit } from "@ember/test-helpers";
import {
  acceptance,
  exists,
  query,
  updateCurrentUser,
} from "discourse/tests/helpers/qunit-helpers";

acceptance("User Preferences - Second Factor", function (needs) {
  needs.user();

  needs.pretender((server, helper) => {
    server.post("/u/second_factors.json", () => {
      return helper.response({
        success: "OK",
        password_required: "true",
        totps: [{ id: 1, name: "one of them" }],
        security_keys: [{ id: 2, name: "key" }],
      });
    });

    server.post("/u/create_second_factor_security_key.json", () => {
      return helper.response({
        challenge:
          "a6d393d12654c130b2273e68ca25ca232d1d7f4c2464c2610fb8710a89d4",
        rp_id: "localhost",
        rp_name: "Discourse",
        supported_algorithms: [-7, -257],
      });
    });

    server.post("/u/enable_second_factor_totp.json", () => {
      return helper.response({ error: "invalid token" });
    });

    server.post("/u/create_second_factor_totp.json", () => {
      return helper.response({
        key: "rcyryaqage3jexfj",
        qr: "data:image/gif;base64,R0lGODlhAQABAAD/ACwAAAAAAQABAAACADs=",
      });
    });

    server.put("/u/security_key.json", () => {
      return helper.response({
        success: "OK",
      });
    });

    server.put("/u/second_factors_backup.json", () => {
      return helper.response({
        backup_codes: ["dsffdsd", "fdfdfdsf", "fddsds"],
      });
    });
  });

  test("second factor totp", async function (assert) {
    await visit("/u/eviltrout/preferences/second-factor");

    assert.ok(exists("#password"), "it has a password input");

    await fillIn("#password", "secrets");
    await click(".user-preferences .btn-primary");
    assert.notOk(exists("#password"), "it hides the password input");

    await click(".new-totp");
    assert.ok(exists(".qr-code img"), "shows qr code image");

    await click(".add-totp");

    assert.ok(
      query(".alert-error").innerHTML.includes("provide a name and the code"),
      "shows name/token missing error message"
    );
  });

  test("second factor security keys", async function (assert) {
    await visit("/u/eviltrout/preferences/second-factor");

    assert.ok(exists("#password"), "it has a password input");

    await fillIn("#password", "secrets");
    await click(".user-preferences .btn-primary");
    assert.notOk(exists("#password"), "it hides the password input");

    await click(".new-security-key");
    assert.ok(exists("#security-key-name"), "shows security key name input");

    await fillIn("#security-key-name", "");

    // The following tests can only run when Webauthn is enabled. This is not
    // always the case, for example on a browser running on a non-standard port
    if (typeof PublicKeyCredential !== "undefined") {
      await click(".add-security-key");

      assert.ok(
        query(".alert-error").innerHTML.includes("provide a name"),
        "shows name missing error message"
      );
    }
  });

  test("delete second factor security method", async function (assert) {
    updateCurrentUser({ moderator: false, admin: false, trust_level: 1 });
    await visit("/u/eviltrout/preferences/second-factor");

    assert.ok(exists("#password"), "it has a password input");

    await fillIn("#password", "secrets");
    await click(".user-preferences .btn-primary");
    await click(".token-based-auth-dropdown .select-kit-header");
    await click("li[data-name='Disable'");

    assert.strictEqual(
      query("#dialog-title").innerText.trim(),
      "Deleting an authenticator"
    );
    await click(".dialog-close");

    assert.ok(
      exists(".security-key .second-factor-item"),
      "User has a physical security key"
    );

    await click(".security-key-dropdown .select-kit-header");
    await click("li[data-name='Disable'");

    assert.strictEqual(
      query("#dialog-title").innerText.trim(),
      "Deleting an authenticator"
    );
    await click(".dialog-footer .btn-danger");
    assert.notOk(
      exists(".security-key .second-factor-item"),
      "security key row is removed after a successful delete"
    );

    await click(".pref-second-factor-disable-all .btn-danger");
    assert.strictEqual(
      query("#dialog-title").innerText.trim(),
      "Are you sure you want to disable two-factor authentication?"
    );
  });
});
