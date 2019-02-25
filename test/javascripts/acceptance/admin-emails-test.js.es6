import { acceptance } from "helpers/qunit-helpers";

acceptance("Admin - Emails", { loggedIn: true });

const email = `
From: "somebody" <somebody@example.com>
To: someone@example.com
Date: Mon, 3 Dec 2018 00:00:00 -0000
Subject: This is some subject
Content-Type: text/plain; charset="UTF-8"

Hello, this is a test!

---

This part should be elided.`.trim();

QUnit.test("shows selected and elided text", async assert => {
  // prettier-ignore
  server.post("/admin/email/advanced-test", () => { // eslint-disable-line no-undef
    return [
      200,
      { "Content-Type": "application/json" },
      {
        format: 1,
        text: "Hello, this is a test!",
        elided: "---\n\nThis part should be elided.",
      }
    ];
  });

  await visit("/admin/email/advanced-test");
  await fillIn("textarea.email-body", email);
  await click(".email-advanced-test button");

  assert.equal(find(".text pre").text(), "Hello, this is a test!");
  assert.equal(
    find(".elided pre").text(),
    "---\n\nThis part should be elided."
  );
});
