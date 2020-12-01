import { acceptance, queryAll } from "discourse/tests/helpers/qunit-helpers";
import { click, fillIn, visit } from "@ember/test-helpers";
import { test } from "qunit";

function pretender(server, helper) {
  server.post("/uploads/lookup-urls", () => {
    return helper.response([
      {
        short_url: "upload://asdsad.png",
        url: "/secure-media-uploads/default/3X/1/asjdiasjdiasida.png",
        short_path: "/uploads/short-url/asdsad.png",
      },
    ]);
  });
}

async function writeInComposer(assert) {
  await visit("/t/internationalization-localization/280");
  await click("#topic-footer-buttons .btn.create");

  await fillIn(".d-editor-input", "[test](upload://abcdefg.png)");

  assert.equal(
    queryAll(".d-editor-preview:visible").html().trim(),
    '<p><a href="/404">test</a></p>'
  );

  await fillIn(".d-editor-input", "[test|attachment](upload://asdsad.png)");
}

acceptance("Composer Attachment", function (needs) {
  needs.user();
  needs.pretender(pretender);

  test("attachments are cooked properly", async function (assert) {
    await writeInComposer(assert);
    assert.equal(
      queryAll(".d-editor-preview:visible").html().trim(),
      '<p><a class="attachment" href="/uploads/short-url/asdsad.png">test</a></p>'
    );
  });
});

acceptance("Composer Attachment - Secure Media Enabled", function (needs) {
  needs.user();
  needs.settings({ secure_media: true });
  needs.pretender(pretender);

  test("attachments are cooked properly when secure media is enabled", async function (assert) {
    await writeInComposer(assert);
    assert.equal(
      queryAll(".d-editor-preview:visible").html().trim(),
      '<p><a class="attachment" href="/secure-media-uploads/default/3X/1/asjdiasjdiasida.png">test</a></p>'
    );
  });
});
