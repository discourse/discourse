import EmailLog from 'admin/models/email-log';

module("Discourse.EmailLog");

test("create", function() {
  ok(EmailLog.create(), "it can be created without arguments");
});
