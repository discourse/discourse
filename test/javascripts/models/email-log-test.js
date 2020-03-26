import EmailLog from "admin/models/email-log";

QUnit.module("Discourse.EmailLog");

QUnit.test("create", assert => {
  assert.ok(EmailLog.create(), "it can be created without arguments");
});

QUnit.test("subfolder support", assert => {
  Discourse.BaseUri = "/forum";
  const attrs = {
    id: 60,
    to_address: "wikiman@asdf.com",
    email_type: "user_linked",
    user_id: 9,
    created_at: "2018-08-08T17:21:52.022Z",
    post_url: "/t/some-pro-tips-for-you/41/5",
    post_description: "Some Pro Tips For You",
    bounced: false,
    user: {
      id: 9,
      username: "wikiman",
      avatar_template:
        "/forum/letter_avatar_proxy/v2/letter/w/dfb087/{size}.png"
    }
  };
  const emailLog = EmailLog.create(attrs);
  assert.equal(
    emailLog.get("post_url"),
    "/forum/t/some-pro-tips-for-you/41/5",
    "includes the subfolder in the post url"
  );
});
