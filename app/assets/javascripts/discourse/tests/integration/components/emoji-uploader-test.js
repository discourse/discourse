import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import selectKit from "discourse/tests/helpers/select-kit-helper";
import {
  createFile,
  discourseModule,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";
import pretender from "discourse/tests/helpers/create-pretender";

discourseModule("Integration | Component | emoji-uploader", function (hooks) {
  setupRenderingTest(hooks);

  const template = hbs` {{emoji-uploader
    emojiGroups=emojiGroups
    done=(action "emojiUploaded")
    id="emoji-uploader"
  }}`;

  hooks.beforeEach(function () {
    this.setProperties({
      emojiGroups: ["default", "coolemojis"],
      actions: {
        emojiUploaded: (upload, group) => {
          this.doneUpload(upload, group);
        },
      },
    });

    pretender.post("/admin/customize/emojis.json", () => {
      return [
        200,
        { "Content-Type": "application/json" },
        {
          group: "default",
          name: "test",
          url:
            "//upload.s3.dualstack.us-east-2.amazonaws.com/original/1X/123.png",
        },
      ];
    });
  });

  componentTest("uses the selected group for the upload", {
    template,

    async test(assert) {
      const done = assert.async();
      await selectKit("#emoji-group-selector").expand();
      await selectKit("#emoji-group-selector").selectRowByValue("coolemojis");

      this.set("doneUpload", (upload, group) => {
        assert.equal("coolemojis", group);
        done();
      });
      const image = createFile("avatar.png");
      await this.container
        .lookup("service:app-events")
        .trigger("upload-mixin:emoji-uploader:add-files", image);
    },
  });

  componentTest("does not clear the selected group between multiple uploads", {
    template,

    async test(assert) {
      const done = assert.async();
      await selectKit("#emoji-group-selector").expand();
      await selectKit("#emoji-group-selector").selectRowByValue("coolemojis");

      let uploadDoneCount = 0;
      this.set("doneUpload", (upload, group) => {
        uploadDoneCount += 1;
        assert.equal("coolemojis", group);

        if (uploadDoneCount === 2) {
          done();
        }
      });

      const image = createFile("avatar.png");
      const image2 = createFile("avatar2.png");
      await this.container
        .lookup("service:app-events")
        .trigger("upload-mixin:emoji-uploader:add-files", [image, image2]);
    },
  });
});
