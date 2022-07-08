import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { fillIn, render } from "@ember/test-helpers";
import { createFile } from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import pretender from "discourse/tests/helpers/create-pretender";
import selectKit from "discourse/tests/helpers/select-kit-helper";

let requestNumber = 1;

module("Integration | Component | emoji-uploader", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    requestNumber = 1;
    this.setProperties({
      emojiGroups: ["default", "coolemojis"],
    });

    pretender.post("/admin/customize/emojis.json", () => {
      if (requestNumber === 1) {
        return [
          200,
          { "Content-Type": "application/json" },
          {
            group: "coolemojis",
            name: "okay",
            url: "//upload.s3.dualstack.us-east-2.amazonaws.com/original/1X/123.png",
          },
        ];
        requestNumber += 1;
      } else if (requestNumber === 2) {
        return [
          200,
          { "Content-Type": "application/json" },
          {
            group: "coolemojis",
            name: null,
            url: "//upload.s3.dualstack.us-east-2.amazonaws.com/original/1X/456.png",
          },
        ];
      }
    });
  });

  test("uses the selected group for the upload", async function (assert) {
    await render(hbs`
      <EmojiUploader
        @id="emoji-uploader"
        @emojiGroups={{this.emojiGroups}}
        @done={{this.doneUpload}}
      />
    `);

    const done = assert.async();
    await selectKit("#emoji-group-selector").expand();
    await selectKit("#emoji-group-selector").selectRowByValue("coolemojis");

    this.set("doneUpload", (upload, group) => {
      assert.strictEqual("coolemojis", group);
      done();
    });
    const image = createFile("avatar.png");

    await this.container
      .lookup("service:app-events")
      .trigger("upload-mixin:emoji-uploader:add-files", image);
  });

  test("does not clear the selected group between multiple uploads", async function (assert) {
    await render(hbs`
      <EmojiUploader
        @id="emoji-uploader"
        @emojiGroups={{this.emojiGroups}}
        @done={{this.doneUpload}}
      />
    `);

    const done = assert.async();
    await selectKit("#emoji-group-selector").expand();
    await selectKit("#emoji-group-selector").selectRowByValue("coolemojis");

    let uploadDoneCount = 0;
    this.set("doneUpload", (upload, group) => {
      uploadDoneCount += 1;
      assert.strictEqual("coolemojis", group);

      if (uploadDoneCount === 2) {
        done();
      }
    });

    const image = createFile("avatar.png");
    const image2 = createFile("avatar2.png");

    await this.container
      .lookup("service:app-events")
      .trigger("upload-mixin:emoji-uploader:add-files", [image, image2]);
  });

  test("clears the name after the first upload to avoid duplicate names", async function (assert) {
    await render(hbs`
      <EmojiUploader
        @id="emoji-uploader"
        @emojiGroups={{this.emojiGroups}}
        @done={{this.doneUpload}}
      />
    `);

    const done = assert.async();
    await selectKit("#emoji-group-selector").expand();
    await selectKit("#emoji-group-selector").selectRowByValue("coolemojis");
    await fillIn("#emoji-name", "okay");

    let uploadDoneCount = 0;
    this.set("doneUpload", (upload) => {
      if (uploadDoneCount === 0) {
        assert.strictEqual(upload.name, "okay");
      }
      uploadDoneCount += 1;

      if (uploadDoneCount === 1) {
        assert.strictEqual(this.name, null);
      }

      if (uploadDoneCount === 2) {
        done();
      }
    });

    const image = createFile("avatar.png");
    const image2 = createFile("avatar2.png");

    await this.container
      .lookup("service:app-events")
      .trigger("upload-mixin:emoji-uploader:add-files", [image, image2]);
  });
});
