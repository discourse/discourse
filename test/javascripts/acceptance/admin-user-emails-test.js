import I18n from "I18n";
import { acceptance } from "helpers/qunit-helpers";

acceptance("Admin - User Emails", { loggedIn: true });

const assertNoSecondary = assert => {
  assert.equal(
    find(".display-row.email .value a").text(),
    "eviltrout@example.com",
    "it should display the primary email"
  );

  assert.equal(
    find(".display-row.secondary-emails .value")
      .text()
      .trim(),
    I18n.t("user.email.no_secondary"),
    "it should not display secondary emails"
  );
};

const assertMultipleSecondary = (assert, firstEmail, secondEmail) => {
  assert.equal(
    find(".display-row.secondary-emails .value li:first-of-type a").text(),
    firstEmail,
    "it should display the first secondary email"
  );

  assert.equal(
    find(".display-row.secondary-emails .value li:last-of-type a").text(),
    secondEmail,
    "it should display the second secondary email"
  );
};

QUnit.test("viewing self without secondary emails", async assert => {
  await visit("/admin/users/1/eviltrout");

  assertNoSecondary(assert);
});

QUnit.test("viewing self with multiple secondary emails", async assert => {
  await visit("/admin/users/3/markvanlan");

  assert.equal(
    find(".display-row.email .value a").text(),
    "markvanlan@example.com",
    "it should display the user's primary email"
  );

  assertMultipleSecondary(
    assert,
    "markvanlan1@example.com",
    "markvanlan2@example.com"
  );
});

QUnit.test("viewing another user with no secondary email", async assert => {
  await visit("/admin/users/1234/regular");
  await click(`.display-row.secondary-emails button`);

  assertNoSecondary(assert);
});

QUnit.test("viewing another account with secondary emails", async assert => {
  await visit("/admin/users/1235/regular1");
  await click(`.display-row.secondary-emails button`);

  assertMultipleSecondary(
    assert,
    "regular2alt1@example.com",
    "regular2alt2@example.com"
  );
});
