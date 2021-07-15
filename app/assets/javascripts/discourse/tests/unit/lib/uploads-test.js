import * as Utilities from "discourse/lib/utilities";
import {
  allowsAttachments,
  allowsImages,
  authorizedExtensions,
  getUploadMarkdown,
  isImage,
  validateUploadedFiles,
} from "discourse/lib/uploads";
import I18n from "I18n";
import User from "discourse/models/user";
import bootbox from "bootbox";
import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import sinon from "sinon";
import { test } from "qunit";

discourseModule("Unit | Utility | uploads", function () {
  test("validateUploadedFiles", function (assert) {
    assert.not(
      validateUploadedFiles(null, { siteSettings: this.siteSettings }),
      "no files are invalid"
    );
    assert.not(
      validateUploadedFiles(undefined, { siteSettings: this.siteSettings }),
      "undefined files are invalid"
    );
    assert.not(
      validateUploadedFiles([], { siteSettings: this.siteSettings }),
      "empty array of files is invalid"
    );
  });

  test("uploading one file", function (assert) {
    sinon.stub(bootbox, "alert");

    assert.not(
      validateUploadedFiles([1, 2], { siteSettings: this.siteSettings })
    );
    assert.ok(bootbox.alert.calledWith(I18n.t("post.errors.too_many_uploads")));
  });

  test("new user cannot upload images", function (assert) {
    this.siteSettings.newuser_max_embedded_media = 0;
    sinon.stub(bootbox, "alert");

    assert.not(
      validateUploadedFiles([{ name: "image.png" }], {
        user: User.create(),
        siteSettings: this.siteSettings,
      }),
      "the upload is not valid"
    );
    assert.ok(
      bootbox.alert.calledWith(
        I18n.t("post.errors.image_upload_not_allowed_for_new_user")
      ),
      "the alert is called"
    );
  });

  test("new user can upload images if allowed", function (assert) {
    this.siteSettings.newuser_max_embedded_media = 1;
    this.siteSettings.default_trust_level = 0;
    sinon.stub(bootbox, "alert");

    assert.ok(
      validateUploadedFiles([{ name: "image.png" }], {
        user: User.create(),
        siteSettings: this.siteSettings,
      })
    );
  });

  test("TL1 can upload images", function (assert) {
    this.siteSettings.newuser_max_embedded_media = 0;
    sinon.stub(bootbox, "alert");

    assert.ok(
      validateUploadedFiles([{ name: "image.png" }], {
        user: User.create({ trust_level: 1 }),
        siteSettings: this.siteSettings,
      })
    );
  });

  test("new user cannot upload attachments", function (assert) {
    this.siteSettings.newuser_max_attachments = 0;
    sinon.stub(bootbox, "alert");

    assert.not(
      validateUploadedFiles([{ name: "roman.txt" }], {
        user: User.create(),
        siteSettings: this.siteSettings,
      })
    );
    assert.ok(
      bootbox.alert.calledWith(
        I18n.t("post.errors.attachment_upload_not_allowed_for_new_user")
      )
    );
  });

  test("ensures an authorized upload", function (assert) {
    sinon.stub(bootbox, "alert");
    assert.not(
      validateUploadedFiles([{ name: "unauthorized.html" }], {
        siteSettings: this.siteSettings,
      })
    );
    assert.ok(
      bootbox.alert.calledWith(
        I18n.t("post.errors.upload_not_authorized", {
          authorized_extensions: authorizedExtensions(
            false,
            this.siteSettings
          ).join(", "),
        })
      )
    );
  });

  test("skipping validation works", function (assert) {
    const files = [{ name: "backup.tar.gz" }];
    sinon.stub(bootbox, "alert");

    assert.not(
      validateUploadedFiles(files, {
        skipValidation: false,
        siteSettings: this.siteSettings,
      })
    );
    assert.ok(
      validateUploadedFiles(files, {
        skipValidation: true,
        siteSettings: this.siteSettings,
      })
    );
  });

  test("staff can upload anything in PM", function (assert) {
    const files = [{ name: "some.docx" }];
    this.siteSettings.authorized_extensions = "jpeg";
    sinon.stub(bootbox, "alert");

    let user = User.create({ moderator: true });
    assert.not(
      validateUploadedFiles(files, { user, siteSettings: this.siteSettings })
    );
    assert.ok(
      validateUploadedFiles(files, {
        isPrivateMessage: true,
        allowStaffToUploadAnyFileInPm: true,
        siteSettings: this.siteSettings,
        user,
      })
    );
  });

  const imageSize = 10 * 1024;

  const dummyBlob = function () {
    const BlobBuilder =
      window.BlobBuilder ||
      window.WebKitBlobBuilder ||
      window.MozBlobBuilder ||
      window.MSBlobBuilder;
    if (BlobBuilder) {
      let bb = new BlobBuilder();
      bb.append([new Int8Array(imageSize)]);
      return bb.getBlob("image/png");
    } else {
      return new Blob([new Int8Array(imageSize)], { type: "image/png" });
    }
  };

  test("allows valid uploads to go through", function (assert) {
    sinon.stub(bootbox, "alert");

    let user = User.create({ trust_level: 1 });

    // image
    let image = { name: "image.png", size: imageSize };
    assert.ok(
      validateUploadedFiles([image], { user, siteSettings: this.siteSettings })
    );
    // pasted image
    let pastedImage = dummyBlob();
    assert.ok(
      validateUploadedFiles([pastedImage], {
        user,
        siteSettings: this.siteSettings,
      })
    );

    assert.not(bootbox.alert.calledOnce);
  });

  test("isImage", function (assert) {
    ["png", "webp", "jpg", "jpeg", "gif", "ico"].forEach((extension) => {
      let image = "image." + extension;
      assert.ok(isImage(image), image + " is recognized as an image");
      assert.ok(
        isImage("http://foo.bar/path/to/" + image),
        image + " is recognized as an image"
      );
    });
    assert.not(isImage("file.txt"));
    assert.not(isImage("http://foo.bar/path/to/file.txt"));
    assert.not(isImage(""));
  });

  test("allowsImages", function (assert) {
    this.siteSettings.authorized_extensions = "jpg|jpeg|gif";
    assert.ok(allowsImages(false, this.siteSettings), "works");

    this.siteSettings.authorized_extensions = ".jpg|.jpeg|.gif";
    assert.ok(
      allowsImages(false, this.siteSettings),
      "works with old extensions syntax"
    );

    this.siteSettings.authorized_extensions = "txt|pdf|*";
    assert.ok(
      allowsImages(false, this.siteSettings),
      "images are allowed when all extensions are allowed"
    );

    this.siteSettings.authorized_extensions = "json|jpg|pdf|txt";
    assert.ok(
      allowsImages(false, this.siteSettings),
      "images are allowed when at least one extension is an image extension"
    );
  });

  test("allowsAttachments", function (assert) {
    this.siteSettings.authorized_extensions = "jpg|jpeg|gif";
    assert.not(
      allowsAttachments(false, this.siteSettings),
      "no attachments allowed by default"
    );

    this.siteSettings.authorized_extensions = "jpg|jpeg|gif|*";
    assert.ok(
      allowsAttachments(false, this.siteSettings),
      "attachments are allowed when all extensions are allowed"
    );

    this.siteSettings.authorized_extensions = "jpg|jpeg|gif|pdf";
    assert.ok(
      allowsAttachments(false, this.siteSettings),
      "attachments are allowed when at least one extension is not an image extension"
    );

    this.siteSettings.authorized_extensions = ".jpg|.jpeg|.gif|.pdf";
    assert.ok(
      allowsAttachments(false, this.siteSettings),
      "works with old extensions syntax"
    );
  });

  function testUploadMarkdown(filename, opts = {}) {
    return getUploadMarkdown(
      Object.assign(
        {
          original_filename: filename,
          filesize: 42,
          thumbnail_width: 100,
          thumbnail_height: 200,
          url: "/uploads/123/abcdef.ext",
        },
        opts
      )
    );
  }

  test("getUploadMarkdown", function (assert) {
    assert.equal(
      testUploadMarkdown("lolcat.gif"),
      "![lolcat|100x200](/uploads/123/abcdef.ext)"
    );
    assert.equal(
      testUploadMarkdown("[foo|bar].png"),
      "![foobar|100x200](/uploads/123/abcdef.ext)"
    );
    assert.equal(
      testUploadMarkdown("file name with space.png"),
      "![file name with space|100x200](/uploads/123/abcdef.ext)"
    );

    assert.equal(
      testUploadMarkdown("image.file.name.with.dots.png"),
      "![image.file.name.with.dots|100x200](/uploads/123/abcdef.ext)"
    );

    const short_url = "uploads://asdaasd.ext";

    assert.equal(
      testUploadMarkdown("important.txt", { short_url }),
      `[important.txt|attachment](${short_url}) (42 Bytes)`
    );
  });

  test("getUploadMarkdown - replaces GUID in image alt text on iOS", function (assert) {
    assert.equal(
      testUploadMarkdown("8F2B469B-6B2C-4213-BC68-57B4876365A0.jpeg"),
      "![8F2B469B-6B2C-4213-BC68-57B4876365A0|100x200](/uploads/123/abcdef.ext)"
    );

    sinon.stub(Utilities, "isAppleDevice").returns(true);
    assert.equal(
      testUploadMarkdown("8F2B469B-6B2C-4213-BC68-57B4876365A0.jpeg"),
      "![image|100x200](/uploads/123/abcdef.ext)"
    );
  });
});
