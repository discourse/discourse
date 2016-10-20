/* global Int8Array:true */
import { blank } from 'helpers/qunit-helpers';
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
  validateUploadedFiles,
  getUploadMarkdown,
  caretRowCol,
  setCaretPosition
} from 'discourse/lib/utilities';

module("lib:utilities");

test("emailValid", function() {
  ok(emailValid('Bob@example.com'), "allows upper case in the first part of emails");
  ok(emailValid('bob@EXAMPLE.com'), "allows upper case in the email domain");
});

test("extractDomainFromUrl", function() {
  equal(extractDomainFromUrl('http://meta.discourse.org:443/random'), 'meta.discourse.org', "extract domain name from url");
  equal(extractDomainFromUrl('meta.discourse.org:443/random'), 'meta.discourse.org', "extract domain regardless of scheme presence");
  equal(extractDomainFromUrl('http://192.168.0.1:443/random'), '192.168.0.1', "works for IP address");
  equal(extractDomainFromUrl('http://localhost:443/random'), 'localhost', "works for localhost");
});

var validUpload = validateUploadedFiles;

test("validateUploadedFiles", function() {
  not(validUpload(null), "no files are invalid");
  not(validUpload(undefined), "undefined files are invalid");
  not(validUpload([]), "empty array of files is invalid");
});

test("uploading one file", function() {
  sandbox.stub(bootbox, "alert");

  not(validUpload([1, 2]));
  ok(bootbox.alert.calledWith(I18n.t('post.errors.too_many_uploads')));
});

test("new user cannot upload images", function() {
  Discourse.SiteSettings.newuser_max_images = 0;
  Discourse.User.resetCurrent(Discourse.User.create());
  sandbox.stub(bootbox, "alert");

  not(validUpload([{name: "image.png"}]), 'the upload is not valid');
  ok(bootbox.alert.calledWith(I18n.t('post.errors.image_upload_not_allowed_for_new_user')), 'the alert is called');
});

test("new user cannot upload attachments", function() {
  Discourse.SiteSettings.newuser_max_attachments = 0;
  sandbox.stub(bootbox, "alert");
  Discourse.User.resetCurrent(Discourse.User.create());

  not(validUpload([{name: "roman.txt"}]));
  ok(bootbox.alert.calledWith(I18n.t('post.errors.attachment_upload_not_allowed_for_new_user')));
});

test("ensures an authorized upload", function() {
  const html = { name: "unauthorized.html" };
  sandbox.stub(bootbox, "alert");

  not(validUpload([html]));
  ok(bootbox.alert.calledWith(I18n.t('post.errors.upload_not_authorized', { authorized_extensions: authorizedExtensions() })));
});

var imageSize = 10 * 1024;

var dummyBlob = function() {
  var BlobBuilder = window.BlobBuilder || window.WebKitBlobBuilder || window.MozBlobBuilder || window.MSBlobBuilder;
  if (BlobBuilder) {
    var bb = new BlobBuilder();
    bb.append([new Int8Array(imageSize)]);
    return bb.getBlob("image/png");
  } else {
    return new Blob([new Int8Array(imageSize)], { "type" : "image\/png" });
  }
};

test("allows valid uploads to go through", function() {
  Discourse.User.resetCurrent(Discourse.User.create());
  Discourse.User.currentProp("trust_level", 1);
  sandbox.stub(bootbox, "alert");

  // image
  var image = { name: "image.png", size: imageSize };
  ok(validUpload([image]));
  // pasted image
  var pastedImage = dummyBlob();
  ok(validUpload([pastedImage]));

  not(bootbox.alert.calledOnce);
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

test("getUploadMarkdown", function() {
  ok(testUploadMarkdown("lolcat.gif") === '<img src="/uploads/123/abcdef.ext" width="100" height="200">');
  ok(testUploadMarkdown("important.txt") === '<a class="attachment" href="/uploads/123/abcdef.ext">important.txt</a> (42 Bytes)\n');
});

test("isAnImage", function() {
  _.each(["png", "jpg", "jpeg", "bmp", "gif", "tif", "tiff", "ico"], function(extension) {
    var image = "image." + extension;
    ok(isAnImage(image), image + " is recognized as an image");
    ok(isAnImage("http://foo.bar/path/to/" + image), image + " is recognized as an image");
  });
  not(isAnImage("file.txt"));
  not(isAnImage("http://foo.bar/path/to/file.txt"));
  not(isAnImage(""));
});

test("avatarUrl", function() {
  var rawSize = getRawSize;
  blank(avatarUrl('', 'tiny'), "no template returns blank");
  equal(avatarUrl('/fake/template/{size}.png', 'tiny'), "/fake/template/" + rawSize(20) + ".png", "simple avatar url");
  equal(avatarUrl('/fake/template/{size}.png', 'large'), "/fake/template/" + rawSize(45) +  ".png", "different size");
});

var setDevicePixelRatio = function(value) {
  if (Object.defineProperty && !window.hasOwnProperty('devicePixelRatio')) {
    Object.defineProperty(window, "devicePixelRatio", { value: 2 });
  } else {
    window.devicePixelRatio = value;
  }
};

test("avatarImg", function() {
  var oldRatio = window.devicePixelRatio;
  setDevicePixelRatio(2);

  var avatarTemplate = "/path/to/avatar/{size}.png";
  equal(avatarImg({avatarTemplate: avatarTemplate, size: 'tiny'}),
        "<img alt='' width='20' height='20' src='/path/to/avatar/40.png' class='avatar'>",
        "it returns the avatar html");

  equal(avatarImg({avatarTemplate: avatarTemplate, size: 'tiny', title: 'evilest trout'}),
        "<img alt='' width='20' height='20' src='/path/to/avatar/40.png' class='avatar' title='evilest trout'>",
        "it adds a title if supplied");

  equal(avatarImg({avatarTemplate: avatarTemplate, size: 'tiny', extraClasses: 'evil fish'}),
        "<img alt='' width='20' height='20' src='/path/to/avatar/40.png' class='avatar evil fish'>",
        "it adds extra classes if supplied");

  blank(avatarImg({avatarTemplate: "", size: 'tiny'}),
        "it doesn't render avatars for invalid avatar template");

  setDevicePixelRatio(oldRatio);
});

test("allowsImages", function() {
  Discourse.SiteSettings.authorized_extensions = "jpg|jpeg|gif";
  ok(allowsImages(), "works");

  Discourse.SiteSettings.authorized_extensions = ".jpg|.jpeg|.gif";
  ok(allowsImages(), "works with old extensions syntax");

  Discourse.SiteSettings.authorized_extensions = "txt|pdf|*";
  ok(allowsImages(), "images are allowed when all extensions are allowed");

  Discourse.SiteSettings.authorized_extensions = "json|jpg|pdf|txt";
  ok(allowsImages(), "images are allowed when at least one extension is an image extension");
});


test("allowsAttachments", function() {
  Discourse.SiteSettings.authorized_extensions = "jpg|jpeg|gif";
  not(allowsAttachments(), "no attachments allowed by default");

  Discourse.SiteSettings.authorized_extensions = "jpg|jpeg|gif|*";
  ok(allowsAttachments(), "attachments are allowed when all extensions are allowed");

  Discourse.SiteSettings.authorized_extensions = "jpg|jpeg|gif|pdf";
  ok(allowsAttachments(), "attachments are allowed when at least one extension is not an image extension");

  Discourse.SiteSettings.authorized_extensions = ".jpg|.jpeg|.gif|.pdf";
  ok(allowsAttachments(), "works with old extensions syntax");
});

test("defaultHomepage", function() {
  Discourse.SiteSettings.top_menu = "latest|top|hot";
  equal(defaultHomepage(), "latest", "default homepage is the first item in the top_menu site setting");
});

test("caretRowCol", () => {
  var textarea = document.createElement('textarea');
  const content = document.createTextNode("01234\n56789\n012345");
  textarea.appendChild(content);
  document.body.appendChild(textarea);

  const assertResult = (setCaretPos, expectedRowNum, expectedColNum) => {
    setCaretPosition(textarea, setCaretPos);

    const result = caretRowCol(textarea);
    equal(result.rowNum, expectedRowNum, "returns the right row of the caret");
    equal(result.colNum, expectedColNum,  "returns the right col of the caret");
  };

  assertResult(0, 1, 0);
  assertResult(5, 1, 5);
  assertResult(6, 2, 0);
  assertResult(11, 2, 5);
  assertResult(14, 3, 2);

  document.body.removeChild(textarea);
});
