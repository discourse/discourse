import {
  validateUploadedFiles,
  authorizedExtensions,
  isImage,
  allowsImages,
  allowsAttachments,
  getUploadMarkdown
} from "discourse/lib/uploads";
import * as Utilities from "discourse/lib/utilities";
import User from "discourse/models/user";

QUnit.module("lib:uploads");

const validUpload = validateUploadedFiles;

QUnit.test("validateUploadedFiles", assert => {
  assert.not(validUpload(null), "no files are invalid");
  assert.not(validUpload(undefined), "undefined files are invalid");
  assert.not(validUpload([]), "empty array of files is invalid");
});

QUnit.test("uploading one file", assert => {
  sandbox.stub(bootbox, "alert");

  assert.not(validUpload([1, 2]));
  assert.ok(bootbox.alert.calledWith(I18n.t("post.errors.too_many_uploads")));
});

QUnit.test("new user cannot upload images", assert => {
  Discourse.SiteSettings.newuser_max_images = 0;
  sandbox.stub(bootbox, "alert");

  assert.not(
    validUpload([{ name: "image.png" }], { user: User.create() }),
    "the upload is not valid"
  );
  assert.ok(
    bootbox.alert.calledWith(
      I18n.t("post.errors.image_upload_not_allowed_for_new_user")
    ),
    "the alert is called"
  );
});

QUnit.test("new user cannot upload attachments", assert => {
  Discourse.SiteSettings.newuser_max_attachments = 0;
  sandbox.stub(bootbox, "alert");

  assert.not(validUpload([{ name: "roman.txt" }], { user: User.create() }));
  assert.ok(
    bootbox.alert.calledWith(
      I18n.t("post.errors.attachment_upload_not_allowed_for_new_user")
    )
  );
});

QUnit.test("ensures an authorized upload", assert => {
  sandbox.stub(bootbox, "alert");
  assert.not(validUpload([{ name: "unauthorized.html" }]));
  assert.ok(
    bootbox.alert.calledWith(
      I18n.t("post.errors.upload_not_authorized", {
        authorized_extensions: authorizedExtensions()
      })
    )
  );
});

QUnit.test("skipping validation works", assert => {
  const files = [{ name: "backup.tar.gz" }];
  sandbox.stub(bootbox, "alert");

  assert.not(validUpload(files, { skipValidation: false }));
  assert.ok(validUpload(files, { skipValidation: true }));
});

QUnit.test("staff can upload anything in PM", assert => {
  const files = [{ name: "some.docx" }];
  Discourse.SiteSettings.authorized_extensions = "jpeg";
  sandbox.stub(bootbox, "alert");

  let user = User.create({ moderator: true });
  assert.not(validUpload(files, { user }));
  assert.ok(
    validUpload(files, {
      isPrivateMessage: true,
      allowStaffToUploadAnyFileInPm: true,
      user
    })
  );
});

const imageSize = 10 * 1024;

const dummyBlob = function() {
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

QUnit.test("allows valid uploads to go through", assert => {
  sandbox.stub(bootbox, "alert");

  let user = User.create({ trust_level: 1 });

  // image
  let image = { name: "image.png", size: imageSize };
  assert.ok(validUpload([image], { user }));
  // pasted image
  let pastedImage = dummyBlob();
  assert.ok(validUpload([pastedImage], { user }));

  assert.not(bootbox.alert.calledOnce);
});

QUnit.test("isImage", assert => {
  ["png", "jpg", "jpeg", "gif", "ico"].forEach(extension => {
    var image = "image." + extension;
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

QUnit.test("allowsImages", assert => {
  Discourse.SiteSettings.authorized_extensions = "jpg|jpeg|gif";
  assert.ok(allowsImages(), "works");

  Discourse.SiteSettings.authorized_extensions = ".jpg|.jpeg|.gif";
  assert.ok(allowsImages(), "works with old extensions syntax");

  Discourse.SiteSettings.authorized_extensions = "txt|pdf|*";
  assert.ok(
    allowsImages(),
    "images are allowed when all extensions are allowed"
  );

  Discourse.SiteSettings.authorized_extensions = "json|jpg|pdf|txt";
  assert.ok(
    allowsImages(),
    "images are allowed when at least one extension is an image extension"
  );
});

QUnit.test("allowsAttachments", assert => {
  Discourse.SiteSettings.authorized_extensions = "jpg|jpeg|gif";
  assert.not(allowsAttachments(), "no attachments allowed by default");

  Discourse.SiteSettings.authorized_extensions = "jpg|jpeg|gif|*";
  assert.ok(
    allowsAttachments(),
    "attachments are allowed when all extensions are allowed"
  );

  Discourse.SiteSettings.authorized_extensions = "jpg|jpeg|gif|pdf";
  assert.ok(
    allowsAttachments(),
    "attachments are allowed when at least one extension is not an image extension"
  );

  Discourse.SiteSettings.authorized_extensions = ".jpg|.jpeg|.gif|.pdf";
  assert.ok(allowsAttachments(), "works with old extensions syntax");
});

function testUploadMarkdown(filename, opts = {}) {
  return getUploadMarkdown(
    Object.assign(
      {
        original_filename: filename,
        filesize: 42,
        thumbnail_width: 100,
        thumbnail_height: 200,
        url: "/uploads/123/abcdef.ext"
      },
      opts
    )
  );
}

QUnit.test("getUploadMarkdown", assert => {
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

QUnit.test(
  "getUploadMarkdown - replaces GUID in image alt text on iOS",
  assert => {
    assert.equal(
      testUploadMarkdown("8F2B469B-6B2C-4213-BC68-57B4876365A0.jpeg"),
      "![8F2B469B-6B2C-4213-BC68-57B4876365A0|100x200](/uploads/123/abcdef.ext)"
    );

    sandbox.stub(Utilities, "isAppleDevice").returns(true);
    assert.equal(
      testUploadMarkdown("8F2B469B-6B2C-4213-BC68-57B4876365A0.jpeg"),
      "![image|100x200](/uploads/123/abcdef.ext)"
    );
  }
);
