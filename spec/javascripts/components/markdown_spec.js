/*global waitsFor:true expect:true describe:true beforeEach:true it:true */

describe("Discourse.Markdown", function() {

  describe("Cooking", function() {

    var cook = function(contents, opts) {
      opts = opts || {};
      opts.mentionLookup = opts.mentionLookup || false;
      return Discourse.Markdown.cook(contents, opts);
    };

    it("surrounds text with paragraphs", function() {
      expect(cook("hello")).toBe("<p>hello</p>");
    });

    it("automatically handles trivial newlines", function() {
      expect(cook("1\n2\n3")).toBe("<p>1 <br>\n2 <br>\n3</p>");
    });

    it("handles quotes properly", function() {
      var cooked = cook("1[quote=\"bob, post:1\"]my quote[/quote]2", {
        topicId: 2,
        lookupAvatar: function(name) { return "" + name; }
      });
      expect(cooked).toBe("<p>1</p><aside class='quote' data-post=\"1\" >\n  <div class='title'>\n    <div class='quote-controls'></div>\n" +
                          "  bob\n  bob\n  said:\n  </div>\n  <blockquote>my quote</blockquote>\n</aside>\n<p> <br>\n2</p>");
    });

    it("includes no avatar if none is found", function() {
      var cooked = cook("1[quote=\"bob, post:1\"]my quote[/quote]2", {
        topicId: 2,
        lookupAvatar: function(name) { return null; }
      });
      expect(cooked).toBe("<p>1</p><aside class='quote' data-post=\"1\" >\n  <div class='title'>\n    <div class='quote-controls'></div>\n" +
                          "  \n  bob\n  said:\n  </div>\n  <blockquote>my quote</blockquote>\n</aside>\n<p> <br>\n2</p>");
    });

    describe("Links", function() {

      it("allows links to contain query params", function() {
        expect(cook("Youtube: http://www.youtube.com/watch?v=1MrpeBRkM5A")).
          toBe('<p>Youtube: <a href="http://www.youtube.com/watch?v=1MrpeBRkM5A">http://www.youtube.com/watch?v=1MrpeBRkM5A</a></p>');
      });

      it("escapes double underscores in URLs", function() {
        expect(cook("Derpy: http://derp.com?__test=1")).toBe('<p>Derpy: <a href="http://derp.com?%5F%5Ftest=1">http://derp.com?__test=1</a></p>');
      });

      it("autolinks something that begins with www", function() {
        expect(cook("Atwood: www.codinghorror.com")).toBe('<p>Atwood: <a href="http://www.codinghorror.com">www.codinghorror.com</a></p>');
      });

      it("autolinks a URL with http://www", function() {
        expect(cook("Atwood: http://www.codinghorror.com")).toBe('<p>Atwood: <a href="http://www.codinghorror.com">http://www.codinghorror.com</a></p>');
      });

      it("autolinks a URL", function() {
        expect(cook("EvilTrout: http://eviltrout.com")).toBe('<p>EvilTrout: <a href="http://eviltrout.com">http://eviltrout.com</a></p>');
      });

      it("supports markdown style links", function() {
        expect(cook("here is [an example](http://twitter.com)")).toBe('<p>here is <a href="http://twitter.com">an example</a></p>');
      });

      it("autolinks a URL with parentheses (like Wikipedia)", function() {
        expect(cook("Batman: http://en.wikipedia.org/wiki/The_Dark_Knight_(film)")).
          toBe('<p>Batman: <a href="http://en.wikipedia.org/wiki/The_Dark_Knight_(film)">http://en.wikipedia.org/wiki/The_Dark_Knight_(film)</a></p>');
      });

    });

    describe("Mentioning", function() {

      it("translates mentions to links", function() {
        expect(cook("Hello @sam", { mentionLookup: (function() { return true; }) })).toBe("<p>Hello <a href='/users/sam' class='mention'>@sam</a></p>");
      });

      it("adds a mention class", function() {
        expect(cook("Hello @EvilTrout")).toBe("<p>Hello <span class='mention'>@EvilTrout</span></p>");
      });

      it("won't add mention class to an email address", function() {
        expect(cook("robin@email.host")).toBe("<p>robin@email.host</p>");
      });

      it("won't be affected by email addresses that have a number before the @ symbol", function() {
        expect(cook("hanzo55@yahoo.com")).toBe("<p>hanzo55@yahoo.com</p>");
      });

      it("supports a @mention at the beginning of a post", function() {
        expect(cook("@EvilTrout yo")).toBe("<p><span class='mention'>@EvilTrout</span> yo</p>");
      });

      it("doesn't do @username mentions inside <pre> or <code> blocks", function() {
        expect(cook("`@EvilTrout yo`")).toBe("<p><code>&#64;EvilTrout yo</code></p>");
      });

      it("deals correctly with multiple <code> blocks", function() {
        expect(cook("`evil` @EvilTrout `trout`")).toBe("<p><code>evil</code> <span class='mention'>@EvilTrout</span> <code>trout</code></p>");
      });

    });

    describe("Oneboxing", function() {

      it("doesn't onebox a link within a list", function() {
        expect(cook("- http://www.textfiles.com/bbs/MINDVOX/FORUMS/ethics\n\n- http://drupal.org")).not.toMatch(/onebox/);
      });

      it("adds a onebox class to a link on its own line", function() {
        expect(cook("http://test.com")).toMatch(/onebox/);
      });

      it("supports multiple links", function() {
        expect(cook("http://test.com\nhttp://test2.com")).toMatch(/onebox[\s\S]+onebox/m);
      });

      it("doesn't onebox links that have trailing text", function() {
        expect(cook("http://test.com bob")).not.toMatch(/onebox/);
      });

      it("works with links that have underscores in them", function() {
        expect(cook("http://en.wikipedia.org/wiki/Homicide:_Life_on_the_Street")).
          toBe("<p><a href=\"http://en.wikipedia.org/wiki/Homicide:_Life_on_the_Street\" class=\"onebox\" target=\"_blank\">http://en.wikipedia.org/wiki/Homicide:_Life_on_the_Street</a></p>");
      });

    });

  });

});