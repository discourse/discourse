import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";

const EMAIL = `
From: "somebody" <somebody@example.com>
To: someone@example.com
Date: Mon, 3 Dec 2018 00:00:00 -0000
Subject: This is some subject
Content-Type: text/plain; charset="UTF-8"

Hello, this is a test!

---

This part should be elided.`;

acceptance("Admin - Emails", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.post("/admin/email/advanced-test", () => {
      return helper.response({
        format: 1,
        text: "Hello, this is a test!",
        elided: "---\n\nThis part should be elided.",
      });
    });
  });

  test("shows selected and elided text", async function (assert) {
    await visit("/admin/email/advanced-test");
    await fillIn("textarea.email-body", EMAIL.trim());
    await click(".email-advanced-test button");

    assert.strictEqual(queryAll(".text pre").text(), "Hello, this is a test!");
    assert.strictEqual(
      queryAll(".elided pre").text(),
      "---\n\nThis part should be elided."
    );
  });
});
