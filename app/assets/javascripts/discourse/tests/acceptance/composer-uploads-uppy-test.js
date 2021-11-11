import {
  acceptance,
  loggedInUser,
  queryAll,
} from "discourse/tests/helpers/qunit-helpers";
import { withPluginApi } from "discourse/lib/plugin-api";
import bootbox from "bootbox";
import { authorizedExtensions } from "discourse/lib/uploads";
import { click, fillIn, visit } from "@ember/test-helpers";
import I18n from "I18n";
import { skip, test } from "qunit";

function pretender(server, helper) {
  server.post("/uploads/lookup-urls", () => {
    return helper.response([
      {
        url:
          "//testbucket.s3.dualstack.us-east-2.amazonaws.com/original/1X/f1095d89269ff22e1818cf54b73e857261851019.jpeg",
        short_path: "/uploads/short-url/yoj8pf9DdIeHRRULyw7i57GAYdz.jpeg",
        short_url: "upload://yoj8pf9DdIeHRRULyw7i57GAYdz.jpeg",
      },
    ]);
  });

  server.post(
    "/uploads.json",
    () => {
      return helper.response({
        extension: "jpeg",
        filesize: 126177,
        height: 800,
        human_filesize: "123 KB",
        id: 202,
        original_filename: "avatar.PNG.jpg",
        retain_hours: null,
        short_path: "/uploads/short-url/yoj8pf9DdIeHRRULyw7i57GAYdz.jpeg",
        short_url: "upload://yoj8pf9DdIeHRRULyw7i57GAYdz.jpeg",
        thumbnail_height: 320,
        thumbnail_width: 690,
        url:
          "//testbucket.s3.dualstack.us-east-2.amazonaws.com/original/1X/f1095d89269ff22e1818cf54b73e857261851019.jpeg",
        width: 1920,
      });
    },
    500 // this delay is important to slow down the uploads a bit so we can click elements in the UI like the cancel button
  );
}

function createFile(name, type = "image/png") {
  // the blob content doesn't matter at all, just want it to be random-ish
  const file = new Blob([(Math.random() + 1).toString(36).substring(2)], {
    type,
  });
  file.name = name;
  return file;
}

acceptance("Uppy Composer Attachment - Upload Placeholder", function (needs) {
  needs.user();
  needs.pretender(pretender);
  needs.settings({
    enable_experimental_composer_uploader: true,
    simultaneous_uploads: 2,
  });

  test("should insert the Uploading placeholder then the complete image placeholder", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn(".d-editor-input", "The image:\n");
    const appEvents = loggedInUser().appEvents;
    const done = assert.async();

    appEvents.on("composer:all-uploads-complete", () => {
      assert.strictEqual(
        queryAll(".d-editor-input").val(),
        "The image:\n![avatar.PNG|690x320](upload://yoj8pf9DdIeHRRULyw7i57GAYdz.jpeg)\n"
      );
      done();
    });

    appEvents.on("composer:upload-started", () => {
      assert.strictEqual(
        queryAll(".d-editor-input").val(),
        "The image:\n[Uploading: avatar.png...]()\n"
      );
    });

    const image = createFile("avatar.png");
    appEvents.trigger("composer:add-files", image);
  });

  test("should error if too many files are added at once", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const appEvents = loggedInUser().appEvents;
    const image = createFile("avatar.png");
    const image1 = createFile("avatar1.png");
    const image2 = createFile("avatar2.png");
    const done = assert.async();
    appEvents.on("composer:uploads-aborted", async () => {
      assert.strictEqual(
        queryAll(".bootbox .modal-body").html(),
        I18n.t("post.errors.too_many_dragged_and_dropped_files", {
          count: 2,
        }),
        "it should warn about too many files added"
      );

      await click(".modal-footer .btn-primary");

      done();
    });

    appEvents.trigger("composer:add-files", [image, image1, image2]);
  });

  test("should error if an unauthorized extension file is added", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const appEvents = loggedInUser().appEvents;
    const jsonFile = createFile("something.json", "application/json");
    const done = assert.async();

    appEvents.on("composer:uploads-aborted", async () => {
      assert.strictEqual(
        queryAll(".bootbox .modal-body").html(),
        I18n.t("post.errors.upload_not_authorized", {
          authorized_extensions: authorizedExtensions(
            false,
            this.siteSettings
          ).join(", "),
        }),
        "it should warn about unauthorized extensions"
      );

      await click(".modal-footer .btn-primary");

      done();
    });

    appEvents.trigger("composer:add-files", [jsonFile]);
  });

  // TODO: Had to comment this out for now; it works fine in Ember CLI but lagging
  // UI updates sink it for the old Ember for some reason. Will re-enable
  // when we make Ember CLI the primary.

  skip("cancelling uploads clears the placeholders out", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn(".d-editor-input", "The image:\n");
    const appEvents = loggedInUser().appEvents;
    const done = assert.async();

    appEvents.on("composer:uploads-cancelled", () => {
      assert.strictEqual(
        queryAll(".d-editor-input").val(),
        "The image:\n",
        "it should clear the cancelled placeholders"
      );
      done();
    });

    let uploadStarted = 0;
    appEvents.on("composer:upload-started", async () => {
      uploadStarted++;

      if (uploadStarted === 2) {
        assert.strictEqual(
          queryAll(".d-editor-input").val(),
          "The image:\n[Uploading: avatar.png...]()\n[Uploading: avatar2.png...]()\n",
          "it should show the upload placeholders when the upload starts"
        );
      }
    });

    appEvents.on("composer:uploads-preprocessing-complete", async () => {
      await click("#cancel-file-upload");
    });

    const image = createFile("avatar.png");
    const image2 = createFile("avatar2.png");
    appEvents.trigger("composer:add-files", [image, image2]);
  });
});

acceptance("Uppy Composer Attachment - Upload Error", function (needs) {
  needs.user();
  needs.pretender((server, helper) => {
    server.post("/uploads.json", () => {
      return helper.response(422, {
        success: false,
        errors: [
          "There was an error uploading the file, the gif was way too cool.",
        ],
      });
    });
  });
  needs.settings({
    enable_experimental_composer_uploader: true,
    simultaneous_uploads: 2,
  });

  test("should show an error message for the failed upload", async function (assert) {
    await visit("/");
    await click("#create-topic");
    await fillIn(".d-editor-input", "The image:\n");
    const appEvents = loggedInUser().appEvents;
    const done = assert.async();

    appEvents.on("composer:upload-error", async () => {
      assert.strictEqual(
        queryAll(".bootbox .modal-body").html(),
        "There was an error uploading the file, the gif was way too cool.",
        "it should show the error message from the server"
      );

      await click(".modal-footer .btn-primary");

      done();
    });

    const image = createFile("avatar.png");
    appEvents.trigger("composer:add-files", image);
  });
});

acceptance("Uppy Composer Attachment - Upload Handler", function (needs) {
  needs.user();
  needs.pretender(pretender);
  needs.settings({
    enable_experimental_composer_uploader: true,
    simultaneous_uploads: 2,
  });
  needs.hooks.beforeEach(() => {
    withPluginApi("0.8.14", (api) => {
      api.addComposerUploadHandler(["png"], (file) => {
        bootbox.alert(`This is an upload handler test for ${file.name}`);
      });
    });
  });

  test("should use upload handler if the matching extension is used and a single file is uploaded", async function (assert) {
    await visit("/");
    await click("#create-topic");
    const image = createFile("handlertest.png");
    const appEvents = loggedInUser().appEvents;
    const done = assert.async();

    appEvents.on("composer:uploads-aborted", async () => {
      assert.strictEqual(
        queryAll(".bootbox .modal-body").html(),
        "This is an upload handler test for handlertest.png",
        "it should show the bootbox triggered by the upload handler"
      );
      await click(".modal-footer .btn");
      done();
    });

    appEvents.trigger("composer:add-files", [image]);
  });
});
