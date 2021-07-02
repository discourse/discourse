import {
  acceptance,
  exists,
  query,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
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

acceptance("Composer Attachment - Cooking", function (needs) {
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

acceptance("Composer Attachment - Upload Placeholder", function (needs) {
  needs.user();

  test("should insert a newline before and after an image when pasting into an empty composer", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const image = createImage("avatar.png", "/images/avatar.png?1", 200, 300);

    await queryAll(".wmd-controls").trigger("fileuploadsend", image);
    assert.equal(
      queryAll(".d-editor-input").val(),
      "[Uploading: avatar.png...]()\n"
    );

    await queryAll(".wmd-controls").trigger("fileuploaddone", image);
    assert.equal(
      queryAll(".d-editor-input").val(),
      "![avatar|200x300](/images/avatar.png?1)\n"
    );
  });

  test("should insert a newline after an image when pasting into a blank line", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn(".d-editor-input", "The image:\n");

    const image = createImage("avatar.png", "/images/avatar.png?1", 200, 300);
    await queryAll(".wmd-controls").trigger("fileuploadsend", image);

    assert.equal(
      queryAll(".d-editor-input").val(),
      "The image:\n[Uploading: avatar.png...]()\n"
    );

    await queryAll(".wmd-controls").trigger("fileuploaddone", image);
    assert.equal(
      queryAll(".d-editor-input").val(),
      "The image:\n![avatar|200x300](/images/avatar.png?1)\n"
    );
  });

  test("should insert a newline before and after an image when pasting into a non blank line", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn(".d-editor-input", "The image:");

    const image = createImage("avatar.png", "/images/avatar.png?1", 200, 300);
    await queryAll(".wmd-controls").trigger("fileuploadsend", image);

    assert.equal(
      queryAll(".d-editor-input").val(),
      "The image:\n[Uploading: avatar.png...]()\n"
    );

    await queryAll(".wmd-controls").trigger("fileuploaddone", image);
    assert.equal(
      queryAll(".d-editor-input").val(),
      "The image:\n![avatar|200x300](/images/avatar.png?1)\n"
    );
  });

  test("should insert a newline before and after an image when pasting with cursor in the middle of the line", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn(".d-editor-input", "The image Text after the image.");
    const textArea = query(".d-editor-input");
    textArea.selectionStart = 10;
    textArea.selectionEnd = 10;

    const image = createImage("avatar.png", "/images/avatar.png?1", 200, 300);
    await queryAll(".wmd-controls").trigger("fileuploadsend", image);

    assert.equal(
      queryAll(".d-editor-input").val(),
      "The image \n[Uploading: avatar.png...]()\nText after the image."
    );

    await queryAll(".wmd-controls").trigger("fileuploaddone", image);
    assert.equal(
      queryAll(".d-editor-input").val(),
      "The image \n![avatar|200x300](/images/avatar.png?1)\nText after the image."
    );
  });

  test("should insert a newline before and after an image when pasting with text selected", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const image = createImage("avatar.png", "/images/avatar.png?1", 200, 300);
    await fillIn(
      ".d-editor-input",
      "The image [paste here] Text after the image."
    );
    const textArea = query(".d-editor-input");
    textArea.selectionStart = 10;
    textArea.selectionEnd = 23;

    await queryAll(".wmd-controls").trigger("fileuploadsend", image);
    assert.equal(
      queryAll(".d-editor-input").val(),
      "The image \n[Uploading: avatar.png...]()\n Text after the image."
    );

    await queryAll(".wmd-controls").trigger("fileuploaddone", image);
    assert.equal(
      queryAll(".d-editor-input").val(),
      "The image \n![avatar|200x300](/images/avatar.png?1)\n Text after the image."
    );
  });

  test("pasting several images", async function (assert) {
    await visit("/");
    await click("#create-topic");

    const image1 = createImage("test.png", "/images/avatar.png?1", 200, 300);
    const image2 = createImage("test.png", "/images/avatar.png?2", 100, 200);
    const image3 = createImage("image.png", "/images/avatar.png?3", 300, 400);
    const image4 = createImage("image.png", "/images/avatar.png?4", 300, 400);

    await queryAll(".wmd-controls").trigger("fileuploadsend", image1);
    assert.equal(
      queryAll(".d-editor-input").val(),
      "[Uploading: test.png...]()\n"
    );

    await queryAll(".wmd-controls").trigger("fileuploadsend", image2);
    assert.equal(
      queryAll(".d-editor-input").val(),
      "[Uploading: test.png...]()\n[Uploading: test.png(1)...]()\n"
    );

    await queryAll(".wmd-controls").trigger("fileuploadsend", image4);
    assert.equal(
      queryAll(".d-editor-input").val(),
      "[Uploading: test.png...]()\n[Uploading: test.png(1)...]()\n[Uploading: image.png...]()\n"
    );

    await queryAll(".wmd-controls").trigger("fileuploadsend", image3);
    assert.equal(
      queryAll(".d-editor-input").val(),
      "[Uploading: test.png...]()\n[Uploading: test.png(1)...]()\n[Uploading: image.png...]()\n[Uploading: image.png(1)...]()\n"
    );

    await queryAll(".wmd-controls").trigger("fileuploaddone", image2);
    assert.equal(
      queryAll(".d-editor-input").val(),
      "[Uploading: test.png...]()\n![test|100x200](/images/avatar.png?2)\n[Uploading: image.png...]()\n[Uploading: image.png(1)...]()\n"
    );

    await queryAll(".wmd-controls").trigger("fileuploaddone", image3);
    assert.equal(
      queryAll(".d-editor-input").val(),
      "[Uploading: test.png...]()\n![test|100x200](/images/avatar.png?2)\n[Uploading: image.png...]()\n![image|300x400](/images/avatar.png?3)\n"
    );

    await queryAll(".wmd-controls").trigger("fileuploaddone", image1);
    assert.equal(
      queryAll(".d-editor-input").val(),
      "![test|200x300](/images/avatar.png?1)\n![test|100x200](/images/avatar.png?2)\n[Uploading: image.png...]()\n![image|300x400](/images/avatar.png?3)\n"
    );
  });

  test("should accept files with unescaped characters", async function (assert) {
    await visit("/");
    await click("#create-topic");

    const image = createImage("ima++ge.png", "/images/avatar.png?4", 300, 400);

    await queryAll(".wmd-controls").trigger("fileuploadsend", image);
    assert.equal(
      queryAll(".d-editor-input").val(),
      "[Uploading: ima++ge.png...]()\n"
    );

    await queryAll(".wmd-controls").trigger("fileuploaddone", image);
    assert.equal(
      queryAll(".d-editor-input").val(),
      "![ima++ge|300x400](/images/avatar.png?4)\n"
    );
  });

  function createImage(name, url, width, height) {
    const file = new Blob([""], { type: "image/png" });
    file.name = name;
    return {
      files: [file],
      result: {
        original_filename: name,
        thumbnail_width: width,
        thumbnail_height: height,
        url: url,
      },
    };
  }
});

acceptance("Composer Attachment - File input", function (needs) {
  needs.user();

  test("shouldn't add to DOM the hidden file input if uploads aren't allowed", async function (assert) {
    this.siteSettings.authorized_extensions = "";
    await visit("/");
    await click("#create-topic");

    assert.notOk(exists("input#file-uploader"));
  });

  test("should fill the accept attribute with allowed file extensions", async function (assert) {
    this.siteSettings.authorized_extensions = "jpg|jpeg|png";
    await visit("/");
    await click("#create-topic");

    assert.ok(exists("input#file-uploader"), "An input is rendered");
    assert.equal(
      query("input#file-uploader").accept,
      ".jpg,.jpeg,.png",
      "Accepted values are correct"
    );
  });

  test("the hidden file input shouldn't have the accept attribute if any file extension is allowed", async function (assert) {
    this.siteSettings.authorized_extensions = "jpg|jpeg|png|*";
    await visit("/");
    await click("#create-topic");

    assert.ok(exists("input#file-uploader"), "An input is rendered");
    assert.notOk(
      query("input#file-uploader").hasAttribute("accept"),
      "The input doesn't contain the accept attribute"
    );
  });
});
