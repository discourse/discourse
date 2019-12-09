import { acceptance } from "helpers/qunit-helpers";

acceptance("Composer Attachment", {
  loggedIn: true,
  pretend(server, helper) {
    server.post("/uploads/lookup-urls", () => {
      return helper.response([
        {
          short_url: "upload://asdsad.png",
          url: "/uploads/default/3X/1/asjdiasjdiasida.png",
          short_path: "/uploads/short-url/asdsad.png"
        }
      ]);
    });
  }
});

QUnit.test("attachments are cooked properly", async assert => {
  await visit("/t/internationalization-localization/280");
  await click("#topic-footer-buttons .btn.create");

  await fillIn(".d-editor-input", "[test](upload://abcdefg.png)");

  assert.equal(
    find(".d-editor-preview:visible")
      .html()
      .trim(),
    '<p><a href="/404">test</a></p>'
  );

  await fillIn(".d-editor-input", "[test|attachment](upload://asdsad.png)");

  assert.equal(
    find(".d-editor-preview:visible")
      .html()
      .trim(),
    '<p><a class="attachment" href="/uploads/short-url/asdsad.png">test</a></p>'
  );
});
