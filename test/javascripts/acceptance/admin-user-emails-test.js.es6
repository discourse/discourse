import { acceptance } from "helpers/qunit-helpers";

acceptance("Admin - User Emails", { loggedIn: true });

const responseWithSecondary = secondaryEmails => {
  return [
    200,
    { "Content-Type": "application/json" },
    {
      id: 1,
      username: "eviltrout",
      email: "eviltrout@example.com",
      secondary_emails: secondaryEmails
    }
  ];
};

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

const assertMultipleSecondary = assert => {
  assert.equal(
    find(".display-row.secondary-emails .value li:first-of-type a").text(),
    "eviltrout1@example.com",
    "it should display the first secondary email"
  );

  assert.equal(
    find(".display-row.secondary-emails .value li:last-of-type a").text(),
    "eviltrout2@example.com",
    "it should display the second secondary email"
  );
};

QUnit.test("viewing self without secondary emails", async assert => {
  // prettier-ignore
  server.get("/admin/users/1.json", () => { // eslint-disable-line no-undef
    return responseWithSecondary([]);
  });

  await visit("/admin/users/1/eviltrout");

  assertNoSecondary(assert);
});

QUnit.test("viewing self with multiple secondary emails", async assert => {
  // prettier-ignore
  server.get("/admin/users/1.json", () => { // eslint-disable-line no-undef
    return responseWithSecondary([
      "eviltrout1@example.com",
      "eviltrout2@example.com",
    ]);
  });

  await visit("/admin/users/1/eviltrout");

  assert.equal(
    find(".display-row.email .value a").text(),
    "eviltrout@example.com",
    "it should display the user's primary email"
  );

  assertMultipleSecondary(assert);
});

QUnit.test("viewing another user with no secondary email", async assert => {
  await visit("/admin/users/1234/regular");
  await click(`.display-row.secondary-emails button`);

  assertNoSecondary(assert);
});

QUnit.test("viewing another account with secondary emails", async assert => {
  // prettier-ignore
  server.get("/u/regular/emails.json", () => { // eslint-disable-line no-undef
    return [
      200,
      { "Content-Type": "application/json" },
      {
        email: "eviltrout@example.com",
        secondary_emails: ["eviltrout1@example.com", "eviltrout2@example.com"]
      }
    ];
  });

  await visit("/admin/users/1234/regular");
  await click(`.display-row.secondary-emails button`);

  assertMultipleSecondary(assert);
});
