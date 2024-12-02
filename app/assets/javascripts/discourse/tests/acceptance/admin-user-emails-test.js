import { click, visit } from "@ember/test-helpers";
import { test } from "qunit";
import { acceptance } from "discourse/tests/helpers/qunit-helpers";
import { i18n } from "discourse-i18n";

function assertNoSecondary(assert) {
  assert
    .dom(".display-row.email .value a")
    .hasText("eviltrout@example.com", "displays the primary email");

  assert
    .dom(".display-row.secondary-emails .value")
    .hasText(
      i18n("user.email.no_secondary"),
      "does not display secondary emails"
    );
}

function assertMultipleSecondary(assert, firstEmail, secondEmail) {
  assert
    .dom(".display-row.secondary-emails .value li:first-of-type a")
    .hasText(firstEmail, "displays the first secondary email");

  assert
    .dom(".display-row.secondary-emails .value li:last-of-type a")
    .hasText(secondEmail, "displays the second secondary email");
}

acceptance("Admin - User Emails", function (needs) {
  needs.user();

  test("viewing self without secondary emails", async function (assert) {
    await visit("/admin/users/1/eviltrout");

    assertNoSecondary(assert);
  });

  test("viewing self with multiple secondary emails", async function (assert) {
    await visit("/admin/users/3/markvanlan");

    assert
      .dom(".display-row.email .value a")
      .hasText("markvanlan@example.com", "displays the user's primary email");

    assertMultipleSecondary(
      assert,
      "markvanlan1@example.com",
      "markvanlan2@example.com"
    );
  });

  test("viewing another user with no secondary email", async function (assert) {
    await visit("/admin/users/1234/regular");
    await click(`.display-row.secondary-emails button`);

    assertNoSecondary(assert);
  });

  test("viewing another account with secondary emails", async function (assert) {
    await visit("/admin/users/1235/regular1");
    await click(`.display-row.secondary-emails button`);

    assertMultipleSecondary(
      assert,
      "regular2alt1@example.com",
      "regular2alt2@example.com"
    );
  });
});
