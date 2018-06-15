import EmailLog from "admin/models/email-log";

QUnit.module("Discourse.EmailLog");

QUnit.test("create", assert => {
  assert.ok(EmailLog.create(), "it can be created without arguments");
});
