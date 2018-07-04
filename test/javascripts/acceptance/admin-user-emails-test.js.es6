import { acceptance } from "helpers/qunit-helpers";

acceptance("Admin - User Emails", { loggedIn: true });

const responseWithSecondary = secondary_emails => {
  return [200, { "Content-Type": "application/json" }, {
    id: 1,
    username: "eviltrout",
    email: "eviltrout@example.com",
    secondary_emails: secondary_emails
  }];
};

const assertNoSecondary = assert => {
  assert.equal(
    find(".display-row.email .value a").text(),
    "eviltrout@example.com",
    "displays primary email"
  );
  assert.equal(
    find(".display-row.secondary-emails .value").text().trim(),
    "No secondary emails",
    "displays no secondary emails"
  );
};

QUnit.test("my account has no secondary emails", assert => {
  server.get("/admin/users/1.json", () => { // eslint-disable-line no-undef
    return responseWithSecondary([]);
  });
  visit("/admin/users/1/eviltrout");

  andThen(() => {
    assertNoSecondary(assert);
  });
});

QUnit.test("my account has one secondary email", assert => {
  server.get("/admin/users/1.json", () => { // eslint-disable-line no-undef
    return responseWithSecondary(["eviltrout1@example.com"]);
  });
  visit("/admin/users/1/eviltrout");

  andThen(() => {
    assert.equal(
      find(".display-row.email .value a").text(),
      "eviltrout@example.com",
      "displays primary email"
    );
    assert.equal(
      find(".display-row.secondary-emails .value a").text(),
      "eviltrout1@example.com",
      "displays secondary email"
    );
  });
});

const assertMultipleSecondary = assert => {
  assert.equal(
    find(".display-row.secondary-emails .value li:first-of-type a").text(),
    "eviltrout1@example.com",
    "displays first secondary email"
  );
  assert.equal(
    find(".display-row.secondary-emails .value li:last-of-type a").text(),
    "eviltrout2@example.com",
    "displays second secondary email"
  );
};

QUnit.test("my account has multiple secondary emails", assert => {
  server.get("/admin/users/1.json", () => { // eslint-disable-line no-undef
    return responseWithSecondary([
      "eviltrout1@example.com",
      "eviltrout2@example.com"
    ]);
  });
  visit("/admin/users/1/eviltrout");

  andThen(() => {
    assertMultipleSecondary(assert);
  });
});

const otherNoSecondaryShared = (assert, button) => {
  visit("/admin/users/1234/regular");
  click(`.display-row.${button} button`);

  andThen(() => {
    assertNoSecondary(assert);
  });
};

QUnit.test("another account has no secondary emails - clicking primary button", assert => {
  otherNoSecondaryShared(assert, "email");
});

QUnit.test("another account has no secondary emails - clicking secondary button", assert => {
  otherNoSecondaryShared(assert, "secondary-emails");
});

const otherMultipleSecondaryShared = (assert, button) => {
  server.get("/u/regular/emails.json", () => { // eslint-disable-line no-undef
    return [200, { "Content-Type": "application/json" }, {
      email: "eviltrout@example.com",
      secondary_emails: ["eviltrout1@example.com", "eviltrout2@example.com"]
    }];
  });

  visit("/admin/users/1234/regular");
  click(`.display-row.${button} button`);

  andThen(() => {
    assertMultipleSecondary(assert);
  });
};

QUnit.test("another account has multiple secondary emails - clicking primary button", assert => {
  otherMultipleSecondaryShared(assert, "email");
});

QUnit.test("another account has multiple secondary emails - clicking secondary button", assert => {
  otherMultipleSecondaryShared(assert, "secondary-emails");
});
