/*global waitsFor:true expect:true describe:true beforeEach:true it:true */

describe("Discourse.Composer", function() {

  describe("replyLength", function() {

    it("returns the length of a basic reply", function() {
      var composer = Discourse.Composer.create({ reply: "basic reply" });
      expect(composer.get('replyLength')).toBe(11);
    });

    it("trims whitespaces", function() {
      var composer = Discourse.Composer.create({ reply: "\nbasic reply\t" });
      expect(composer.get('replyLength')).toBe(11);
    });

    it("removes quotes", function() {
      var composer = Discourse.Composer.create({ reply: "1[quote=]not counted[/quote]2[quote=]at all[/quote]3" });
      expect(composer.get('replyLength')).toBe(3);
    });

    it("handles nested quotes correctly", function() {
      var composer = Discourse.Composer.create({ reply: "1[quote=]not[quote=]counted[/quote]yay[/quote]2" });
      expect(composer.get('replyLength')).toBe(2);
    });

  });

});
