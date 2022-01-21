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
import { fillIn } from "@ember/test-helpers";

let requestNumber = 1;

discourseModule("Integration | Component | emoji-uploader", function (hooks) {
  setupRenderingTest(hooks);

  const template = hbs` {{emoji-uploader
    emojiGroups=emojiGroups
    done=doneUpload
    id="emoji-uploader"
  }}`;

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
            name: "okey",
            url:
              "//upload.s3.dualstack.us-east-2.amazonaws.com/original/1X/123.png",
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
            url:
              "//upload.s3.dualstack.us-east-2.amazonaws.com/original/1X/456.png",
          },
        ];
      }
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

  componentTest(
    "clears the name after the first upload to avoid duplicate names",
    {
      template,

      async test(assert) {
        const done = assert.async();
        await selectKit("#emoji-group-selector").expand();
        await selectKit("#emoji-group-selector").selectRowByValue("coolemojis");
        await fillIn("#emoji-name", "okey");

        let uploadDoneCount = 0;
        this.set("doneUpload", (upload) => {
          if (uploadDoneCount === 0) {
            assert.equal(upload.name, "okey");
          }
          uploadDoneCount += 1;

          if (uploadDoneCount === 1) {
            assert.equal(this.name, null);
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
      },
    }
  );
});
