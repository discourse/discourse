module("Discourse.Utilities");

var utils = Discourse.Utilities;

test("emailValid", function() {
  ok(utils.emailValid('Bob@example.com'), "allows upper case in the first part of emails");
  ok(utils.emailValid('bob@EXAMPLE.com'), "allows upper case in the email domain");
});


var validUpload = utils.validateFilesForUpload;

test("validateFilesForUpload", function() {
  ok(!validUpload(null), "no files are invalid");
  ok(!validUpload(undefined), "undefined files are invalid");
  ok(!validUpload([]), "empty array of files is invalid");
});

test("uploading one file", function() {
  this.stub(bootbox, "alert");

  ok(!validUpload([1, 2]));
  ok(bootbox.alert.calledWith(Em.String.i18n('post.errors.too_many_uploads')));
});

test("ensures an authorized upload", function() {
  var html = { name: "unauthorized.html" };
  var extensions = Discourse.SiteSettings.authorized_extensions.replace(/\|/g, ", ");
  this.stub(bootbox, "alert");

  ok(!validUpload([html]));
  ok(bootbox.alert.calledWith(Em.String.i18n('post.errors.upload_not_authorized', { authorized_extensions: extensions })));
});

test("prevents files that are too big from being uploaded", function() {
  var image = { name: "image.png", size: 10 * 1024 };
  Discourse.SiteSettings.max_upload_size_kb = 5;
  this.stub(bootbox, "alert");

  ok(!validUpload([image]));
  ok(bootbox.alert.calledWith(Em.String.i18n('post.errors.upload_too_large', { max_size_kb: 5 })));
});

test("allows valid uploads to go through", function() {
  var image = { name: "image.png", size: 10 * 1024 };
  Discourse.SiteSettings.max_upload_size_kb = 15;
  this.stub(bootbox, "alert");

  ok(validUpload([image]));
  ok(!bootbox.alert.calledOnce);
});

var isAuthorized = function (filename) {
  return utils.isAuthorizedUpload({ name: filename });
};

test("isAuthorizedUpload", function() {
  ok(isAuthorized("image.png"));
  ok(isAuthorized("image.jpg"));
  ok(!isAuthorized("image.txt"));
  ok(!isAuthorized(""));
});
