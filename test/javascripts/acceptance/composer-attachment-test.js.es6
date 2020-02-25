import { acceptance } from "helpers/qunit-helpers";

function setupPretender(server, helper) {
  server.post("/uploads/lookup-urls", () => {
    return helper.response([
      {
        short_url: "upload://asdsad.png",
        url: "/secure-media-uploads/default/3X/1/asjdiasjdiasida.png",
        short_path: "/uploads/short-url/asdsad.png"
      }
    ]);
  });
}

async function writeInComposer(assert) {
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
}

acceptance("Composer Attachment", {
  loggedIn: true,
  pretend(server, helper) {
    setupPretender(server, helper);
  }
});

QUnit.test("attachments are cooked properly", async assert => {
  await writeInComposer(assert);
  assert.equal(
    find(".d-editor-preview:visible")
      .html()
      .trim(),
    '<p><a class="attachment" href="/uploads/short-url/asdsad.png">test</a></p>'
  );
});

acceptance("Composer Attachment - Secure Media Enabled", {
  loggedIn: true,
  settings: {
    secure_media: true
  },
  pretend(server, helper) {
    setupPretender(server, helper);
  }
});

QUnit.test(
  "attachments are cooked properly when secure media is enabled",
  async assert => {
    await writeInComposer(assert);
    assert.equal(
      find(".d-editor-preview:visible")
        .html()
        .trim(),
      '<p><a class="attachment" href="/secure-media-uploads/default/3X/1/asjdiasjdiasida.png">test</a></p>'
    );
  }
);
