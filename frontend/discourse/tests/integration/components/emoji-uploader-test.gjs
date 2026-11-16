/* eslint-disable qunit/no-conditional-assertions */
import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import EmojiUploader from "discourse/admin/components/emoji-uploader";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { createFile } from "discourse/tests/helpers/qunit-helpers";
import selectKit from "discourse/tests/helpers/select-kit-helper";

let requestNumber;

module("Integration | Component | EmojiUploader", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    requestNumber = 0;
    this.emojiGroups = ["default", "cool-emojis"];

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
    const done = assert.async();
    const onDone = (upload, group) => {
      assert.strictEqual(group, "cool-emojis");
      done();
    };

    await render(
      <template>
        <EmojiUploader @done={{onDone}} @emojiGroups={{this.emojiGroups}} />
      </template>
    );

    await selectKit("#emoji-group-selector").expand();
    await selectKit("#emoji-group-selector").selectRowByValue("cool-emojis");

    const image = createFile("avatar.png");

    await this.container
      .lookup("service:app-events")
      .trigger("upload-mixin:emoji-uploader:add-files", image);
  });

  test("does not clear the selected group between multiple uploads", async function (assert) {
    const done = assert.async();
    let uploadDoneCount = 0;
    const onDone = (upload, group) => {
      uploadDoneCount++;
      assert.strictEqual(group, "cool-emojis");

      if (uploadDoneCount === 2) {
        done();
      }
    };

    await render(
      <template>
        <EmojiUploader @done={{onDone}} @emojiGroups={{this.emojiGroups}} />
      </template>
    );

    await selectKit("#emoji-group-selector").expand();
    await selectKit("#emoji-group-selector").selectRowByValue("cool-emojis");

    const image = createFile("avatar.png");
    const image2 = createFile("avatar2.png");

    await this.container
      .lookup("service:app-events")
      .trigger("upload-mixin:emoji-uploader:add-files", [image, image2]);
  });

  test("clears the name after the first upload to avoid duplicate names", async function (assert) {
    const done = assert.async();
    let uploadDoneCount = 0;
    const onDone = (upload) => {
      uploadDoneCount++;

      if (uploadDoneCount === 1) {
        assert.strictEqual(upload.name, "okay");
      }

      if (uploadDoneCount === 2) {
        assert.strictEqual(upload.name, null);
        done();
      }
    };

    await render(
      <template>
        <EmojiUploader @done={{onDone}} @emojiGroups={{this.emojiGroups}} />
      </template>
    );

    await selectKit("#emoji-group-selector").expand();
    await selectKit("#emoji-group-selector").selectRowByValue("cool-emojis");
    await fillIn("#emoji-name", "okay");

    const image = createFile("avatar.png");
    const image2 = createFile("avatar2.png");
    await this.container
      .lookup("service:app-events")
      .trigger("upload-mixin:emoji-uploader:add-files", [image, image2]);
  });

  test("sets the created_by field with username", async function (assert) {
    const done = assert.async();
    const onDone = (upload) => {
      assert.strictEqual(upload.created_by, "benji");
      done();
    };

    await render(
      <template>
        <EmojiUploader
          @createdBy={{this.createdBy}}
          @done={{onDone}}
          @emojiGroups={{this.emojiGroups}}
        />
      </template>
    );

    const image = createFile("avatar.png");
    await this.container
      .lookup("service:app-events")
      .trigger("upload-mixin:emoji-uploader:add-files", [image]);
  });
});
