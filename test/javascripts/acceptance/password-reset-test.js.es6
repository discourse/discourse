import { acceptance } from "helpers/qunit-helpers";
import PreloadStore from "preload-store";
import { parsePostData } from "helpers/create-pretender";

acceptance("Password Reset", {
  beforeEach() {
    const response = object => {
      return [200, { "Content-Type": "application/json" }, object];
    };

    // prettier-ignore
    server.get("/u/confirm-email-token/myvalidtoken.json", () => { //eslint-disable-line
      return response({ success: "OK" });
    });

    // prettier-ignore
    server.put("/u/password-reset/myvalidtoken.json", request => { //eslint-disable-line
      const body = parsePostData(request.requestBody);
      if (body.password === "jonesyAlienSlayer") {
        return response({
          success: false,
          errors: { password: ["is the name of your cat"] }
        });
      } else {
        return response({
          success: "OK",
          message: I18n.t("password_reset.success")
        });
      }
    });

    // prettier-ignore
    server.get("/u/confirm-email-token/requiretwofactor.json", () => { //eslint-disable-line
      return response({ success: "OK" });
    });

    // prettier-ignore
    server.put("/u/password-reset/requiretwofactor.json", request => { //eslint-disable-line
      const body = parsePostData(request.requestBody);
      if (
        body.password === "perf3ctly5ecur3" &&
        body.second_factor_token === "123123"
      ) {
        return response({
          success: "OK",
          message: I18n.t("password_reset.success")
        });
      } else if (body.second_factor_token === "123123") {
        return response({ success: false, errors: { password: ["invalid"] } });
      } else {
        return response({
          success: false,
          message: "invalid token",
          errors: { user_second_factors: ["invalid token"] }
        });
      }
    });
  }
});

QUnit.test("Password Reset Page", assert => {
  PreloadStore.store("password_reset", { is_developer: false });

  visit("/u/password-reset/myvalidtoken");
  andThen(() => {
    assert.ok(exists(".password-reset input"), "shows the input");
  });

  fillIn(".password-reset input", "perf3ctly5ecur3");
  andThen(() => {
    assert.ok(exists(".password-reset .tip.good"), "input looks good");
  });

  fillIn(".password-reset input", "123");
  andThen(() => {
    assert.ok(exists(".password-reset .tip.bad"), "input is not valid");
    assert.ok(
      find(".password-reset .tip.bad")
        .html()
        .indexOf(I18n.t("user.password.too_short")) > -1,
      "password too short"
    );
  });

  fillIn(".password-reset input", "jonesyAlienSlayer");
  click(".password-reset form button");
  andThen(() => {
    assert.ok(exists(".password-reset .tip.bad"), "input is not valid");
    assert.ok(
      find(".password-reset .tip.bad")
        .html()
        .indexOf("is the name of your cat") > -1,
      "server validation error message shows"
    );
  });

  fillIn(".password-reset input", "perf3ctly5ecur3");
  click(".password-reset form button");
  andThen(() => {
    assert.ok(!exists(".password-reset form"), "form is gone");
  });
});

QUnit.test("Password Reset Page With Second Factor", assert => {
  PreloadStore.store("password_reset", {
    is_developer: false,
    second_factor_required: true
  });

  visit("/u/password-reset/requiretwofactor");

  andThen(() => {
    assert.notOk(exists("#new-account-password"), "does not show the input");
    assert.ok(exists("#second-factor"), "shows the second factor prompt");
  });

  fillIn("input#second-factor", "0000");
  click(".password-reset form button");

  andThen(() => {
    assert.ok(exists(".alert-error"), "shows 2 factor error");

    assert.ok(
      find(".alert-error")
        .html()
        .indexOf("invalid token") > -1,
      "shows server validation error message"
    );
  });

  fillIn("input#second-factor", "123123");
  click(".password-reset form button");

  andThen(() => {
    assert.notOk(exists(".alert-error"), "hides error");
    assert.ok(exists("#new-account-password"), "shows the input");
  });

  fillIn(".password-reset input", "perf3ctly5ecur3");
  click(".password-reset form button");

  andThen(() => {
    assert.ok(!exists(".password-reset form"), "form is gone");
  });
});
