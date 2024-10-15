import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { acceptance, query } from "discourse/tests/helpers/qunit-helpers";

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
  test("shows selected and elided text", async function (assert) {
    pretender.post("/admin/email/advanced-test", () => {
      return response({
        format: 1,
        text: "Hello, this is a test!",
        elided: "---\n\nThis part should be elided.",
      });
    });

    await visit("/admin/email/advanced-test");
    await fillIn("textarea.email-body", EMAIL.trim());
    await click(".email-advanced-test button");

    assert.dom(".text pre").hasText("Hello, this is a test!");
    assert.dom(".elided pre").hasText("---\n\nThis part should be elided.");
  });

  test("displays received errors when testing emails", async function (assert) {
    pretender.get("/admin/email.json", () => {
      return response({});
    });

    pretender.post("/admin/email/test", () => {
      return response(422, { errors: ["some error"] });
    });

    await visit("/admin/email");
    await fillIn(".admin-controls input", "test@example.com");
    await click(".btn-primary");

    assert.ok(query("#dialog-holder").innerText.includes("some error"));
    assert.ok(
      query("#dialog-holder .dialog-body b"),
      "Error message can contain html"
    );
    await click(".dialog-overlay");
  });
});
