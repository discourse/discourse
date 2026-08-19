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

  test("a bouncing address is flagged before the addresses are revealed", async function (assert) {
    await visit("/admin/users/1235/regular1");

    assert
      .dom(".display-row.email .email-bounce--unrevealed")
      .exists(
        "warns without spending a check_email audit entry on the address"
      );

    await click(`.display-row.secondary-emails button`);

    assert
      .dom(".display-row.email .email-bounce--unrevealed")
      .doesNotExist(
        "gives way to the per-address badge once they are revealed"
      );
  });

  test("bounce state is shown against the address that bounced", async function (assert) {
    await visit("/admin/users/1235/regular1");
    await click(`.display-row.secondary-emails button`);

    assert
      .dom(".display-row.email .email-bounce__link")
      .includesText("6", "shows the primary address's bounce score");

    assert
      .dom(".display-row.secondary-emails li:first-of-type .email-bounce")
      .doesNotExist("leaves a secondary address in good standing alone");

    assert
      .dom(".display-row.secondary-emails li:last-of-type .email-bounce__link")
      .hasText("Bounce score 2", "rounds off the float residue in the score");

    assert.dom(".display-row.email .email-bounce__explanation").hasText(
      i18n("admin.user.bounce_score_state.threshold_reached", {
        date: moment("2100-01-01T00:00:00.000Z").format("ll"),
      }),
      "explains a score at or above the threshold"
    );

    assert
      .dom(
        ".display-row.secondary-emails li:last-of-type .email-bounce__explanation"
      )
      .includesText(
        i18n("admin.user.bounce_score_state.some", {
          date: moment("2100-01-01T00:00:00.000Z").format("ll"),
        }),
        "explains a score below the threshold"
      );

    assert.dom(".display-row.email .email-bounce__reset").hasAttribute(
      "aria-label",
      i18n("admin.user.reset_bounce_score.title", {
        email: "regular2@example.com",
      }),
      "names the address each Reset button acts on"
    );
  });

  test("resetting one address leaves the others alone", async function (assert) {
    await visit("/admin/users/1235/regular1");
    await click(`.display-row.secondary-emails button`);
    await click(".display-row.email .email-bounce__reset");

    assert
      .dom(".display-row.email .email-bounce")
      .doesNotExist("clears the address that was reset");

    assert
      .dom(".display-row.secondary-emails li:last-of-type .email-bounce__link")
      .includesText("2", "keeps the other address's score");
  });
});
