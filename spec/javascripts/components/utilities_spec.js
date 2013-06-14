/*global waitsFor:true expect:true describe:true beforeEach:true it:true spyOn:true */

describe("Discourse.Utilities", function() {

  describe("emailValid", function() {

    it("allows upper case in first part of emails", function() {
      expect(Discourse.Utilities.emailValid('Bob@example.com')).toBe(true);
    });

    it("allows upper case in domain of emails", function() {
      expect(Discourse.Utilities.emailValid('bob@EXAMPLE.com')).toBe(true);
    });

  });

  describe("validateFilesForUpload", function() {

    it("returns false when file is undefined", function() {
      expect(Discourse.Utilities.validateFilesForUpload(null)).toBe(false);
      expect(Discourse.Utilities.validateFilesForUpload(undefined)).toBe(false);
    });

    it("returns false when file there is no file", function() {
      expect(Discourse.Utilities.validateFilesForUpload([])).toBe(false);
    });

    it("supports only one file", function() {
      spyOn(bootbox, 'alert');
      spyOn(Em.String, 'i18n');
      expect(Discourse.Utilities.validateFilesForUpload([1, 2])).toBe(false);
      expect(bootbox.alert).toHaveBeenCalled();
      expect(Em.String.i18n).toHaveBeenCalledWith('post.errors.upload_too_many_images');
    });

    it("supports only an image", function() {
      var html = { type: "text/html" };
      spyOn(bootbox, 'alert');
      spyOn(Em.String, 'i18n');
      expect(Discourse.Utilities.validateFilesForUpload([html])).toBe(false);
      expect(bootbox.alert).toHaveBeenCalled();
      expect(Em.String.i18n).toHaveBeenCalledWith('post.errors.only_images_are_supported');
    });

    it("prevents the upload of a too large image", function() {
      var image = { type: "image/png", size: 10 * 1024 };
      Discourse.SiteSettings.max_upload_size_kb = 5;
      spyOn(bootbox, 'alert');
      spyOn(Em.String, 'i18n');
      expect(Discourse.Utilities.validateFilesForUpload([image])).toBe(false);
      expect(bootbox.alert).toHaveBeenCalled();
      expect(Em.String.i18n).toHaveBeenCalledWith('post.errors.upload_too_large', { max_size_kb: 5 });
    });

    it("works", function() {
      var image = { type: "image/png", size: 10 * 1024 };
      Discourse.SiteSettings.max_upload_size_kb = 15;
      expect(Discourse.Utilities.validateFilesForUpload([image])).toBe(true);
    });

  });

});
