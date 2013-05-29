/*global waitsFor:true expect:true describe:true beforeEach:true it:true spyOn:true */

describe("Discourse.Category", function() {

  describe("slugFor", function() {

    it("returns the slug when it exists", function() {
      expect(Discourse.Category.slugFor({ slug: 'hello' })).toBe("hello");
    });

    it("returns id-category when slug is an empty string", function() {
      expect(Discourse.Category.slugFor({ id: 123, slug: '' })).toBe("123-category");
    });

    it("returns id-category without a slug", function() {
      expect(Discourse.Category.slugFor({ id: 456 })).toBe("456-category");
    });

  });

});