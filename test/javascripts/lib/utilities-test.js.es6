/* global Int8Array:true */
import {
  emailValid,
  extractDomainFromUrl,
  isAnImage,
  avatarUrl,
  authorizedExtensions,
  allowsImages,
  allowsAttachments,
  getRawSize,
  avatarImg,
  defaultHomepage,
  setDefaultHomepage,
  validateUploadedFiles,
  getUploadMarkdown,
  caretRowCol,
  setCaretPosition,
  fillMissingDates
} from "discourse/lib/utilities";
import * as Utilities from "discourse/lib/utilities";

QUnit.module("lib:utilities");

QUnit.test("emailValid", assert => {
  assert.ok(
    emailValid("Bob@example.com"),
    "allows upper case in the first part of emails"
  );
  assert.ok(
    emailValid("bob@EXAMPLE.com"),
    "allows upper case in the email domain"
  );
});

QUnit.test("extractDomainFromUrl", assert => {
  assert.equal(
    extractDomainFromUrl("http://meta.discourse.org:443/random"),
    "meta.discourse.org",
    "extract domain name from url"
  );
  assert.equal(
    extractDomainFromUrl("meta.discourse.org:443/random"),
    "meta.discourse.org",
    "extract domain regardless of scheme presence"
  );
  assert.equal(
    extractDomainFromUrl("http://192.168.0.1:443/random"),
    "192.168.0.1",
    "works for IP address"
  );
  assert.equal(
    extractDomainFromUrl("http://localhost:443/random"),
    "localhost",
    "works for localhost"
  );
});

var validUpload = validateUploadedFiles;

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
  Discourse.User.resetCurrent(Discourse.User.create());
  sandbox.stub(bootbox, "alert");

  assert.not(validUpload([{ name: "image.png" }]), "the upload is not valid");
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
  Discourse.User.resetCurrent(Discourse.User.create());

  assert.not(validUpload([{ name: "roman.txt" }]));
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

QUnit.test("staff can upload anything in PM", assert => {
  const files = [{ name: "some.docx" }];
  Discourse.SiteSettings.authorized_extensions = "jpeg";
  Discourse.User.resetCurrent(Discourse.User.create({ moderator: true }));

  sandbox.stub(bootbox, "alert");

  assert.not(validUpload(files));
  assert.ok(
    validUpload(files, {
      isPrivateMessage: true,
      allowStaffToUploadAnyFileInPm: true
    })
  );
});

var imageSize = 10 * 1024;

var dummyBlob = function() {
  var BlobBuilder =
    window.BlobBuilder ||
    window.WebKitBlobBuilder ||
    window.MozBlobBuilder ||
    window.MSBlobBuilder;
  if (BlobBuilder) {
    var bb = new BlobBuilder();
    bb.append([new Int8Array(imageSize)]);
    return bb.getBlob("image/png");
  } else {
    return new Blob([new Int8Array(imageSize)], { type: "image/png" });
  }
};

QUnit.test("allows valid uploads to go through", assert => {
  Discourse.User.resetCurrent(Discourse.User.create());
  Discourse.User.currentProp("trust_level", 1);
  sandbox.stub(bootbox, "alert");

  // image
  var image = { name: "image.png", size: imageSize };
  assert.ok(validUpload([image]));
  // pasted image
  var pastedImage = dummyBlob();
  assert.ok(validUpload([pastedImage]));

  assert.not(bootbox.alert.calledOnce);
});

var testUploadMarkdown = function(filename) {
  return getUploadMarkdown({
    original_filename: filename,
    filesize: 42,
    width: 100,
    height: 200,
    url: "/uploads/123/abcdef.ext"
  });
};

QUnit.test("getUploadMarkdown", assert => {
  assert.equal(
    testUploadMarkdown("lolcat.gif"),
    "![lolcat|100x200](/uploads/123/abcdef.ext)"
  );
  assert.equal(
    testUploadMarkdown("[foo|bar].png"),
    "![%5Bfoo%7Cbar%5D|100x200](/uploads/123/abcdef.ext)"
  );
  assert.ok(
    testUploadMarkdown("important.txt") ===
      '<a class="attachment" href="/uploads/123/abcdef.ext">important.txt</a> (42 Bytes)\n'
  );
});

QUnit.test("replaces GUID in image alt text on iOS", assert => {
  assert.equal(
    testUploadMarkdown("8F2B469B-6B2C-4213-BC68-57B4876365A0.jpeg"),
    "![8F2B469B-6B2C-4213-BC68-57B4876365A0|100x200](/uploads/123/abcdef.ext)"
  );

  sandbox.stub(Utilities, "isAppleDevice").returns(true);
  assert.equal(
    testUploadMarkdown("8F2B469B-6B2C-4213-BC68-57B4876365A0.jpeg"),
    "![image|100x200](/uploads/123/abcdef.ext)"
  );
});

QUnit.test("isAnImage", assert => {
  _.each(["png", "jpg", "jpeg", "bmp", "gif", "tif", "tiff", "ico"], function(
    extension
  ) {
    var image = "image." + extension;
    assert.ok(isAnImage(image), image + " is recognized as an image");
    assert.ok(
      isAnImage("http://foo.bar/path/to/" + image),
      image + " is recognized as an image"
    );
  });
  assert.not(isAnImage("file.txt"));
  assert.not(isAnImage("http://foo.bar/path/to/file.txt"));
  assert.not(isAnImage(""));
});

QUnit.test("avatarUrl", assert => {
  var rawSize = getRawSize;
  assert.blank(avatarUrl("", "tiny"), "no template returns blank");
  assert.equal(
    avatarUrl("/fake/template/{size}.png", "tiny"),
    "/fake/template/" + rawSize(20) + ".png",
    "simple avatar url"
  );
  assert.equal(
    avatarUrl("/fake/template/{size}.png", "large"),
    "/fake/template/" + rawSize(45) + ".png",
    "different size"
  );
});

var setDevicePixelRatio = function(value) {
  if (Object.defineProperty && !window.hasOwnProperty("devicePixelRatio")) {
    Object.defineProperty(window, "devicePixelRatio", { value: 2 });
  } else {
    window.devicePixelRatio = value;
  }
};

QUnit.test("avatarImg", assert => {
  var oldRatio = window.devicePixelRatio;
  setDevicePixelRatio(2);

  var avatarTemplate = "/path/to/avatar/{size}.png";
  assert.equal(
    avatarImg({ avatarTemplate: avatarTemplate, size: "tiny" }),
    "<img alt='' width='20' height='20' src='/path/to/avatar/40.png' class='avatar'>",
    "it returns the avatar html"
  );

  assert.equal(
    avatarImg({
      avatarTemplate: avatarTemplate,
      size: "tiny",
      title: "evilest trout"
    }),
    "<img alt='' width='20' height='20' src='/path/to/avatar/40.png' class='avatar' title='evilest trout'>",
    "it adds a title if supplied"
  );

  assert.equal(
    avatarImg({
      avatarTemplate: avatarTemplate,
      size: "tiny",
      extraClasses: "evil fish"
    }),
    "<img alt='' width='20' height='20' src='/path/to/avatar/40.png' class='avatar evil fish'>",
    "it adds extra classes if supplied"
  );

  assert.blank(
    avatarImg({ avatarTemplate: "", size: "tiny" }),
    "it doesn't render avatars for invalid avatar template"
  );

  setDevicePixelRatio(oldRatio);
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

QUnit.test("defaultHomepage", assert => {
  Discourse.SiteSettings.top_menu = "latest|top|hot";
  assert.equal(
    defaultHomepage(),
    "latest",
    "default homepage is the first item in the top_menu site setting"
  );
  var meta = document.createElement("meta");
  meta.name = "discourse_current_homepage";
  meta.content = "hot";
  document.body.appendChild(meta);
  assert.equal(
    defaultHomepage(),
    "hot",
    "default homepage is pulled from <meta name=discourse_current_homepage>"
  );
  document.body.removeChild(meta);
});

QUnit.test("setDefaultHomepage", assert => {
  var meta = document.createElement("meta");
  meta.name = "discourse_current_homepage";
  meta.content = "hot";
  document.body.appendChild(meta);
  setDefaultHomepage("top");
  assert.equal(
    meta.content,
    "top",
    "default homepage set by setDefaultHomepage"
  );
  document.body.removeChild(meta);
});

QUnit.test("caretRowCol", assert => {
  var textarea = document.createElement("textarea");
  const content = document.createTextNode("01234\n56789\n012345");
  textarea.appendChild(content);
  document.body.appendChild(textarea);

  const assertResult = (setCaretPos, expectedRowNum, expectedColNum) => {
    setCaretPosition(textarea, setCaretPos);

    const result = caretRowCol(textarea);
    assert.equal(
      result.rowNum,
      expectedRowNum,
      "returns the right row of the caret"
    );
    assert.equal(
      result.colNum,
      expectedColNum,
      "returns the right col of the caret"
    );
  };

  assertResult(0, 1, 0);
  assertResult(5, 1, 5);
  assertResult(6, 2, 0);
  assertResult(11, 2, 5);
  assertResult(14, 3, 2);

  document.body.removeChild(textarea);
});

QUnit.test("fillMissingDates", assert => {
  const startDate = "2017-11-12"; // YYYY-MM-DD
  const endDate = "2017-12-12"; // YYYY-MM-DD
  const data =
    '[{"x":"2017-11-12","y":3},{"x":"2017-11-27","y":2},{"x":"2017-12-06","y":9},{"x":"2017-12-11","y":2}]';

  assert.equal(
    fillMissingDates(JSON.parse(data), startDate, endDate).length,
    31,
    "it returns a JSON array with 31 dates"
  );
});
