import { fillIn, render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { createFile } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

let requestNumber;

module("Integration | Component | emoji-uploader", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    requestNumber = 0;
    this.setProperties({
      emojiGroups: ["default", "cool-emojis"],
    });

    pretender.post("/admin/config/emoji.json", () => {
      requestNumber++;

      if (requestNumber === 1) {
        return response({
          group: "cool-emojis",
          name: "okay",
          created_by: "benji",
          url: "//upload.s3.dualstack.us-east-2.amazonaws.com/original/1X/123.png",
        });
      } else if (requestNumber === 2) {
        return response({
          group: "cool-emojis",
          name: null,
          url: "//upload.s3.dualstack.us-east-2.amazonaws.com/original/1X/456.png",
        });
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
    await selectKit("#emoji-group-selector").selectRowByValue("cool-emojis");

    this.set("doneUpload", (upload, group) => {
      assert.strictEqual(group, "cool-emojis");
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
    await selectKit("#emoji-group-selector").selectRowByValue("cool-emojis");

    let uploadDoneCount = 0;
    this.set("doneUpload", (upload, group) => {
      uploadDoneCount++;
      assert.strictEqual(group, "cool-emojis");

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
    await selectKit("#emoji-group-selector").selectRowByValue("cool-emojis");
    await fillIn("#emoji-name", "okay");

    let uploadDoneCount = 0;
    this.set("doneUpload", (upload) => {
      uploadDoneCount++;

      if (uploadDoneCount === 1) {
        assert.strictEqual(upload.name, "okay");
      }

      if (uploadDoneCount === 2) {
        assert.strictEqual(upload.name, null);
        done();
      }
    });

    const image = createFile("avatar.png");
    const image2 = createFile("avatar2.png");
    await this.container
      .lookup("service:app-events")
      .trigger("upload-mixin:emoji-uploader:add-files", [image, image2]);
  });

  test("sets the created_by field with username", async function (assert) {
    await render(hbs`
      <EmojiUploader
        @id="emoji-uploader"
        @emojiGroups={{this.emojiGroups}}
        @createdBy={{this.createdBy}}
        @done={{this.doneUpload}}
      />
    `);

    const done = assert.async();

    this.set("doneUpload", (upload) => {
      assert.strictEqual(upload.created_by, "benji");
      done();
    });

    const image = createFile("avatar.png");
    await this.container
      .lookup("service:app-events")
      .trigger("upload-mixin:emoji-uploader:add-files", [image]);
  });
});
