/*global waitsFor:true expect:true describe:true beforeEach:true it:true */

describe("Discourse.Utilities", function() {

  describe("categoryUrlId", function() {

    it("returns the slug when it exists", function() {
      expect(Discourse.Utilities.categoryUrlId({ slug: 'hello' })).toBe("hello");
    });

    it("returns id-category when slug is an empty string", function() {
      expect(Discourse.Utilities.categoryUrlId({ id: 123, slug: '' })).toBe("123-category");
    });

    it("returns id-category without a slug", function() {
      expect(Discourse.Utilities.categoryUrlId({ id: 456 })).toBe("456-category");
    });

  });

  describe("emailValid", function() {

    it("allows upper case in first part of emails", function() {
      expect(Discourse.Utilities.emailValid('Bob@example.com')).toBe(true);
    });

    it("allows upper case in domain of emails", function() {
      expect(Discourse.Utilities.emailValid('bob@EXAMPLE.com')).toBe(true);
    });

  });

});
