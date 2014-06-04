module("Discourse.Utilities");

var utils = Discourse.Utilities;

test("emailValid", function() {
  ok(utils.emailValid('Bob@example.com'), "allows upper case in the first part of emails");
  ok(utils.emailValid('bob@EXAMPLE.com'), "allows upper case in the email domain");
});

var validUpload = utils.validateUploadedFiles;

test("validateUploadedFiles", function() {
  not(validUpload(null), "no files are invalid");
  not(validUpload(undefined), "undefined files are invalid");
  not(validUpload([]), "empty array of files is invalid");
});

test("uploading one file", function() {
  this.stub(bootbox, "alert");

  not(validUpload([1, 2]));
  ok(bootbox.alert.calledWith(I18n.t('post.errors.too_many_uploads')));
});

test("new user cannot upload images", function() {
  Discourse.SiteSettings.newuser_max_images = 0;
  this.stub(bootbox, "alert");

  not(validUpload([{name: "image.png"}]), 'the upload is not valid');
  ok(bootbox.alert.calledWith(I18n.t('post.errors.image_upload_not_allowed_for_new_user')), 'the alert is called');
});

test("new user cannot upload attachments", function() {
  Discourse.SiteSettings.newuser_max_attachments = 0;
  this.stub(bootbox, "alert");

  not(validUpload([{name: "roman.txt"}]));
  ok(bootbox.alert.calledWith(I18n.t('post.errors.attachment_upload_not_allowed_for_new_user')));
});

test("ensures an authorized upload", function() {
  var html = { name: "unauthorized.html" };
  var extensions = Discourse.SiteSettings.authorized_extensions.replace(/\|/g, ", ");
  this.stub(bootbox, "alert");

  not(validUpload([html]));
  ok(bootbox.alert.calledWith(I18n.t('post.errors.upload_not_authorized', { authorized_extensions: extensions })));
});

test("prevents files that are too big from being uploaded", function() {
  var image = { name: "image.png", size: 10 * 1024 };
  Discourse.SiteSettings.max_image_size_kb = 5;
  Discourse.User.currentProp("trust_level", 1);
  this.stub(bootbox, "alert");

  not(validUpload([image]));
  ok(bootbox.alert.calledWith(I18n.t('post.errors.image_too_large', { max_size_kb: 5 })));
});

var dummyBlob = function() {
  var BlobBuilder = window.BlobBuilder || window.WebKitBlobBuilder || window.MozBlobBuilder || window.MSBlobBuilder;
  if (BlobBuilder) {
    var bb = new BlobBuilder();
    bb.append([1]);
    return bb.getBlob("image/png");
  } else {
    return new Blob([1], { "type" : "image\/png" });
  }
};

test("allows valid uploads to go through", function() {
  Discourse.User.currentProp("trust_level", 1);
  Discourse.SiteSettings.max_image_size_kb = 15;
  this.stub(bootbox, "alert");

  // image
  var image = { name: "image.png", size: 10 * 1024 };
  ok(validUpload([image]));
  // pasted image
  var pastedImage = dummyBlob();
  ok(validUpload([pastedImage]));

  not(bootbox.alert.calledOnce);
});

var getUploadMarkdown = function(filename) {
  return utils.getUploadMarkdown({
    original_filename: filename,
    filesize: 42,
    width: 100,
    height: 200,
    url: "/uploads/123/abcdef.ext"
  });
};

test("getUploadMarkdown", function() {
  ok(getUploadMarkdown("lolcat.gif") === '<img src="/uploads/123/abcdef.ext" width="100" height="200">');
  ok(getUploadMarkdown("important.txt") === '<a class="attachment" href="/uploads/123/abcdef.ext">important.txt</a> (42 Bytes)');
});

test("isAnImage", function() {
  _.each(["png", "jpg", "jpeg", "bmp", "gif", "tif", "tiff"], function(extension) {
    var image = "image." + extension;
    ok(utils.isAnImage(image), image + " is recognized as an image");
    ok(utils.isAnImage("http://foo.bar/path/to/" + image), image + " is recognized as an image");
  });
  not(utils.isAnImage("file.txt"));
  not(utils.isAnImage("http://foo.bar/path/to/file.txt"));
  not(utils.isAnImage(""));
});

test("avatarUrl", function() {
  blank(utils.avatarUrl('', 'tiny'), "no template returns blank");
  equal(utils.avatarUrl('/fake/template/{size}.png', 'tiny'), "/fake/template/" + 20*window.devicePixelRatio + ".png", "simple avatar url");
  equal(utils.avatarUrl('/fake/template/{size}.png', 'large'), "/fake/template/" + 45*window.devicePixelRatio +  ".png", "different size");
});

test("avatarImg", function() {
  var oldRatio = window.devicePixelRatio;
  window.devicePixelRatio = 2;

  var avatarTemplate = "/path/to/avatar/{size}.png";
  equal(utils.avatarImg({avatarTemplate: avatarTemplate, size: 'tiny'}),
        "<img width='20' height='20' src='/path/to/avatar/40.png' class='avatar'>",
        "it returns the avatar html");

  equal(utils.avatarImg({avatarTemplate: avatarTemplate, size: 'tiny', title: 'evilest trout'}),
        "<img width='20' height='20' src='/path/to/avatar/40.png' class='avatar' title='evilest trout'>",
        "it adds a title if supplied");

  equal(utils.avatarImg({avatarTemplate: avatarTemplate, size: 'tiny', extraClasses: 'evil fish'}),
        "<img width='20' height='20' src='/path/to/avatar/40.png' class='avatar evil fish'>",
        "it adds extra classes if supplied");

  blank(utils.avatarImg({avatarTemplate: "", size: 'tiny'}),
        "it doesn't render avatars for invalid avatar template");

  window.devicePixelRatio = oldRatio;
});

test("allowsAttachments", function() {
  Discourse.SiteSettings.authorized_extensions = "jpg|jpeg|gif";
  not(utils.allowsAttachments(), "no attachments allowed by default");

  Discourse.SiteSettings.authorized_extensions = "jpg|jpeg|gif|*";
  ok(utils.allowsAttachments(), "attachments are allowed when all extensions are allowed");

  Discourse.SiteSettings.authorized_extensions = "jpg|jpeg|gif|pdf";
  ok(utils.allowsAttachments(), "attachments are allowed when at least one extension is not an image extension");
});

test("defaultHomepage", function() {
  Discourse.SiteSettings.top_menu = "latest|top|hot";
  equal(utils.defaultHomepage(), "latest", "default homepage is the first item in the top_menu site setting");
});

module("Discourse.Utilities.cropAvatar with animated avatars", {
  setup: function() { Discourse.SiteSettings.allow_animated_avatars = true; }
});

asyncTestDiscourse("cropAvatar", function() {
  expect(1);

  utils.cropAvatar("/path/to/avatar.gif", "image/gif").then(function(avatarTemplate) {
    equal(avatarTemplate, "/path/to/avatar.gif", "returns the url to the gif when animated gif are enabled");
    start();
  });
});
