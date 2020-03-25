import { acceptance } from "helpers/qunit-helpers";
import PreloadStore from "preload-store";
import { parsePostData } from "helpers/create-pretender";

acceptance("Password Reset", {
  pretend(server, helper) {
    server.get("/u/confirm-email-token/myvalidtoken.json", () =>
      helper.response(200, { success: "OK" })
    );

    server.get("/u/confirm-email-token/requiretwofactor.json", () =>
      helper.response(200, { success: "OK" })
    );

    server.put("/u/password-reset/myvalidtoken.json", request => {
      const body = parsePostData(request.requestBody);
      if (body.password === "jonesyAlienSlayer") {
        return helper.response(200, {
          success: false,
          errors: { password: ["is the name of your cat"] }
        });
      } else {
        return helper.response(200, {
          success: "OK",
          message: I18n.t("password_reset.success")
        });
      }
    });

    server.put("/u/password-reset/requiretwofactor.json", request => {
      const body = parsePostData(request.requestBody);
      if (
        body.password === "perf3ctly5ecur3" &&
        body.second_factor_token === "123123"
      ) {
        return helper.response(200, {
          success: "OK",
          message: I18n.t("password_reset.success")
        });
      } else if (body.second_factor_token === "123123") {
        return helper.response(200, {
          success: false,
          errors: { password: ["invalid"] }
        });
      } else {
        return helper.response(200, {
          success: false,
          message: "invalid token",
          errors: { user_second_factors: ["invalid token"] }
        });
      }
    });
  }
});

QUnit.test("Password Reset Page", async assert => {
  PreloadStore.store("password_reset", { is_developer: false });

  await visit("/u/password-reset/myvalidtoken");
  assert.ok(exists(".password-reset input"), "shows the input");

  await fillIn(".password-reset input", "perf3ctly5ecur3");
  assert.ok(exists(".password-reset .tip.good"), "input looks good");

  await fillIn(".password-reset input", "123");
  assert.ok(exists(".password-reset .tip.bad"), "input is not valid");
  assert.ok(
    find(".password-reset .tip.bad")
      .html()
      .indexOf(I18n.t("user.password.too_short")) > -1,
    "password too short"
  );

  await fillIn(".password-reset input", "jonesyAlienSlayer");
  await click(".password-reset form button");
  assert.ok(exists(".password-reset .tip.bad"), "input is not valid");
  assert.ok(
    find(".password-reset .tip.bad")
      .html()
      .indexOf("is the name of your cat") > -1,
    "server validation error message shows"
  );

  await fillIn(".password-reset input", "perf3ctly5ecur3");
  await click(".password-reset form button");
  assert.ok(!exists(".password-reset form"), "form is gone");
});

QUnit.test("Password Reset Page With Second Factor", async assert => {
  PreloadStore.store("password_reset", {
    is_developer: false,
    second_factor_required: true
  });

  await visit("/u/password-reset/requiretwofactor");

  assert.notOk(exists("#new-account-password"), "does not show the input");
  assert.ok(exists("#second-factor"), "shows the second factor prompt");

  await fillIn("input#second-factor", "0000");
  await click(".password-reset form button");

  assert.ok(exists(".alert-error"), "shows 2 factor error");

  assert.ok(
    find(".alert-error")
      .html()
      .indexOf("invalid token") > -1,
    "shows server validation error message"
  );

  await fillIn("input#second-factor", "123123");
  await click(".password-reset form button");

  assert.notOk(exists(".alert-error"), "hides error");
  assert.ok(exists("#new-account-password"), "shows the input");

  await fillIn(".password-reset input", "perf3ctly5ecur3");
  await click(".password-reset form button");

  assert.ok(!exists(".password-reset form"), "form is gone");
});
