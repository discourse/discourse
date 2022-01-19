import pretender from "discourse/tests/helpers/create-pretender";
import componentTest, {
  setupRenderingTest,
} from "discourse/tests/helpers/component-test";
import {
  createFile,
  discourseModule,
} from "discourse/tests/helpers/qunit-helpers";
import hbs from "htmlbars-inline-precompile";

discourseModule("Integration | Component | avatar-uploader", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.setProperties({
      actions: {
        uploadComplete: (upload) => {
          this.doneUpload(upload);
        },
      },
    });
    pretender.post(`/uploads.json`, () => {
      return [
        200,
        { "Content-Type": "application/json" },
        {
          extension: "jpeg",
          filesize: 126177,
          height: 50,
          human_filesize: "123 KB",
          id: 202,
          original_filename: "avatar.PNG.jpg",
          retain_hours: null,
          short_path: "/uploads/short-url/yoj8pf9DdIeHRRULyw7i57GAYdz.jpeg",
          short_url: "upload://yoj8pf9DdIeHRRULyw7i57GAYdz.jpeg",
          thumbnail_height: 50,
          thumbnail_width: 50,
          url:
            "//testbucket.s3.dualstack.us-east-2.amazonaws.com/original/1X/f1095d89269ff22e1818cf54b73e857261851019.jpeg",
          width: 50,
        },
      ];
    });
  });

  componentTest("uploads successfully", {
    template: hbs`{{avatar-uploader id="avatar-uploader" done=(action "uploadComplete")}}`,

    async test(assert) {
      const done = assert.async();

      this.set("doneUpload", (upload) => {
        assert.notOk(
          upload === null,
          "Doesn't show the 'group_mentioned' notice in a quote"
        );
        done();
      });
      const image = createFile("avatar.png");
      await this.container
        .lookup("service:app-events")
        .trigger("upload-mixin:avatar-uploader:add-files", image);
    },
  });
});
