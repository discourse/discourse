import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import sinon from "sinon";
import PreloadStore from "discourse/lib/preload-store";
import DiscourseURL from "discourse/lib/url";
import { parsePostData } from "discourse/tests/helpers/create-pretender";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Password Reset", function (needs) {
  needs.pretender((server, helper) => {
    server.get("/u/confirm-email-token/myvalidtoken.json", () =>
      helper.response({ success: "OK" })
    );

    server.get("/u/confirm-email-token/requiretwofactor.json", () =>
      helper.response({ success: "OK" })
    );

    server.put("/u/password-reset/myvalidtoken.json", (request) => {
      const body = parsePostData(request.requestBody);
      if (body.password === "jonesyAlienSlayer") {
        return helper.response({
          success: false,
          errors: { password: ["is the name of your cat"] },
          friendly_messages: ["Password is the name of your cat"],
        });
      } else {
        return helper.response({
          success: "OK",
          message:
            "You successfully changed your password and are now logged in.",
        });
      }
    });

    server.put("/u/password-reset/requiretwofactor.json", (request) => {
      const body = parsePostData(request.requestBody);
      if (
        body.password === "perf3ctly5ecur3" &&
        body.second_factor_token === "123123"
      ) {
        return helper.response({
          success: "OK",
          message:
            "You successfully changed your password and are now logged in.",
        });
      } else if (body.second_factor_token === "123123") {
        return helper.response({
          success: false,
          errors: { password: ["invalid"] },
          friendly_messages: ["Password is invalid"],
        });
      } else {
        return helper.response({
          success: false,
          message: "invalid token",
          errors: { user_second_factors: ["invalid token"] },
        });
      }
    });
  });

  test("Password Reset Page", async function (assert) {
    PreloadStore.store("password_reset", { is_developer: false });

    await visit("/u/password-reset/myvalidtoken");
    assert.dom(".password-reset input").exists("shows the input");

    await fillIn(".password-reset input", "perf3ctly5ecur3");
    assert.dom(".password-reset .tip.good").exists("input looks good");

    await fillIn(".password-reset input", "jonesyAlienSlayer");
    await click(".password-reset form button[type='submit']");
    assert.dom(".password-reset .tip.bad").exists("input is not valid");
    assert
      .dom(".password-reset .tip.bad")
      .includesHtml(
        "Password is the name of your cat",
        "server validation error message shows"
      );

    assert
      .dom("#new-account-password[type='password']")
      .exists("password is masked by default");
    await click(".toggle-password-mask");
    assert
      .dom("#new-account-password[type='text']")
      .exists("password is unmasked after toggle is clicked");

    await fillIn(".password-reset input", "perf3ctly5ecur3");
    sinon.stub(DiscourseURL, "redirectTo");
    await click(".password-reset form button[type='submit']");
    assert.true(DiscourseURL.redirectTo.calledWith("/"), "form is gone");
  });

  test("Password Reset Page With Second Factor", async function (assert) {
    PreloadStore.store("password_reset", {
      is_developer: false,
      second_factor_required: true,
    });

    await visit("/u/password-reset/requiretwofactor");

    assert.dom("#new-account-password").doesNotExist("does not show the input");
    assert.dom("#second-factor").exists("shows the second factor prompt");

    await fillIn("input#second-factor", "0000");
    await click(".password-reset form button");

    assert.dom(".alert-error").exists("shows 2FA error");

    assert
      .dom(".alert-error")
      .includesHtml("invalid token", "shows server validation error message");

    await fillIn("input#second-factor", "123123");
    await click(".password-reset form button");

    assert.dom(".alert-error").doesNotExist("hides error");
    assert.dom("#new-account-password").exists("shows the input");

    await fillIn(".password-reset input", "perf3ctly5ecur3");

    sinon.stub(DiscourseURL, "redirectTo");
    await click(".password-reset form button[type='submit']");
    assert.true(
      DiscourseURL.redirectTo.calledWith("/"),
      "it redirects after submitting form"
    );
  });
});
