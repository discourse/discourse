import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import cookie, { removeCookie } from "discourse/lib/cookie";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";

acceptance("Login query redirect - modal", function (needs) {
  needs.settings({ login_required: false, full_page_login: false });
  needs.hooks.beforeEach(() => {
    removeCookie("destination_url");
  });

  test("access page with query param", async function (assert) {
    let redirectParam = "/categories";
    await visit(`/login?redirect=${redirectParam}`);
    assert.strictEqual(
      cookie("destination_url"),
      redirectParam,
      "Redirect cookie is set correctly"
    );
  });

  test("access page with query param navigate away and revisit login", async function (assert) {
    let redirectParam = "/categories";
    await visit(`/login?redirect=${redirectParam}`);
    await click(".modal-close");
    await visit("/login");
    assert.strictEqual(
      cookie("destination_url"),
      undefined,
      "Redirect cookie is undefined"
    );
  });
});

acceptance("Login query redirect - full page", function (needs) {
  needs.settings({ login_required: false, full_page_login: true });
  needs.hooks.beforeEach(() => {
    removeCookie("destination_url");
  });

  test("access page with query param", async function (assert) {
    let redirectParam = "/categories";
    await visit(`/login?redirect=${redirectParam}`);
    assert.strictEqual(
      cookie("destination_url"),
      redirectParam,
      "Redirect cookie is set correctly"
    );
  });

  test("access page with query param navigate away and revisit login", async function (assert) {
    let redirectParam = "/categories";
    await visit(`/login?redirect=${redirectParam}`);
    await visit("/login");
    assert.strictEqual(
      cookie("destination_url"),
      undefined,
      "Redirect cookie is undefined"
    );
  });
});
