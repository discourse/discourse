module("Discourse.Utilities");

var utils = Discourse.Utilities;

test("emailValid", function() {
  ok(utils.emailValid('Bob@example.com'), "allows upper case in the first part of emails");
  ok(utils.emailValid('bob@EXAMPLE.com'), "allows upper case in the email domain");
});

var validUpload = utils.validateUploadedFiles;

test("validateUploadedFiles", function() {
  ok(!validUpload(null), "no files are invalid");
  ok(!validUpload(undefined), "undefined files are invalid");
  ok(!validUpload([]), "empty array of files is invalid");
});

test("uploading one file", function() {
  this.stub(bootbox, "alert");

  ok(!validUpload([1, 2]));
  ok(bootbox.alert.calledWith(I18n.t('post.errors.too_many_uploads')));
});

test("new user cannot upload images", function() {
  Discourse.SiteSettings.newuser_max_images = 0;
  this.stub(Discourse.User, 'currentProp').withArgs("trust_level").returns(0);
  this.stub(bootbox, "alert");

  ok(!validUpload([{name: "image.png"}]));
  ok(bootbox.alert.calledWith(I18n.t('post.errors.image_upload_not_allowed_for_new_user')));
});

test("new user cannot upload attachments", function() {
  Discourse.SiteSettings.newuser_max_attachments = 0;
  this.stub(Discourse.User, 'currentProp').withArgs("trust_level").returns(0);
  this.stub(bootbox, "alert");

  ok(!validUpload([{name: "roman.txt"}]));
  ok(bootbox.alert.calledWith(I18n.t('post.errors.attachment_upload_not_allowed_for_new_user')));
});

test("ensures an authorized upload", function() {
  var html = { name: "unauthorized.html" };
  var extensions = Discourse.SiteSettings.authorized_extensions.replace(/\|/g, ", ");
  this.stub(bootbox, "alert");

  ok(!validUpload([html]));
  ok(bootbox.alert.calledWith(I18n.t('post.errors.upload_not_authorized', { authorized_extensions: extensions })));
});

test("prevents files that are too big from being uploaded", function() {
  var image = { name: "image.png", size: 10 * 1024 };
  Discourse.SiteSettings.max_image_size_kb = 5;
  this.stub(bootbox, "alert");

  ok(!validUpload([image]));
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
  Discourse.SiteSettings.max_image_size_kb = 15;
  this.stub(bootbox, "alert");

  // image
  var image = { name: "image.png", size: 10 * 1024 };
  ok(validUpload([image]));
  // pasted image
  var pastedImage = dummyBlob();
  ok(validUpload([pastedImage]));

  ok(!bootbox.alert.calledOnce);
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
  ok(getUploadMarkdown("important.txt") === '<a class="attachment" href="/uploads/123/abcdef.ext">important.txt</a><span class="size">(42 Bytes)</span>');
});

test("isAnImage", function() {
  _.each(["png", "jpg", "jpeg", "bmp", "gif", "tif", "tiff"], function(extension) {
    var image = "image." + extension;
    ok(utils.isAnImage(image), image + " is recognized as an image");
    ok(utils.isAnImage("http://foo.bar/path/to/" + image), image + " is recognized as an image");
  });
  ok(!utils.isAnImage("file.txt"));
  ok(!utils.isAnImage("http://foo.bar/path/to/file.txt"));
  ok(!utils.isAnImage(""));
});

test("avatarUrl", function() {
  blank(Discourse.Utilities.avatarUrl('', 'tiny'), "no avatar url returns blank");
  blank(Discourse.Utilities.avatarUrl('this is not a username', 'tiny'), "invalid username returns blank");

  equal(Discourse.Utilities.avatarUrl('eviltrout', 'tiny'), "/users/eviltrout/avatar/20?__ws=", "simple avatar url");
  equal(Discourse.Utilities.avatarUrl('eviltrout', 'large'), "/users/eviltrout/avatar/45?__ws=", "different size");
  equal(Discourse.Utilities.avatarUrl('EvilTrout', 'tiny'), "/users/eviltrout/avatar/20?__ws=", "lowercases username");
  equal(Discourse.Utilities.avatarUrl('eviltrout', 'tiny', 'test{size}'), "test20", "replaces the size in a template");
});

test("avatarUrl with a baseUrl", function() {
  Discourse.BaseUrl = "http://try.discourse.org";
  equal(Discourse.Utilities.avatarUrl('eviltrout', 'tiny'), "/users/eviltrout/avatar/20?__ws=http%3A%2F%2Ftry.discourse.org", "simple avatar url");
});

test("avatarImg", function() {
  equal(Discourse.Utilities.avatarImg({username: 'eviltrout', size: 'tiny'}),
        "<img width='20' height='20' src='/users/eviltrout/avatar/20?__ws=' class='avatar'>",
        "it returns the avatar html");

  equal(Discourse.Utilities.avatarImg({username: 'eviltrout', size: 'tiny', title: 'evilest trout'}),
        "<img width='20' height='20' src='/users/eviltrout/avatar/20?__ws=' class='avatar' title='evilest trout'>",
        "it adds a title if supplied");

  equal(Discourse.Utilities.avatarImg({username: 'eviltrout', size: 'tiny', extraClasses: 'evil fish'}),
        "<img width='20' height='20' src='/users/eviltrout/avatar/20?__ws=' class='avatar evil fish'>",
        "it adds extra classes if supplied");

  blank(Discourse.Utilities.avatarImg({username: 'weird*username', size: 'tiny'}),
        "it doesn't render avatars for invalid usernames");
});
