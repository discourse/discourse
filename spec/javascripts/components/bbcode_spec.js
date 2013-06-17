/*global waitsFor:true expect:true describe:true beforeEach:true it:true md5:true */

describe("Discourse.BBCode", function() {

  var format = Discourse.BBCode.format;

  describe("quoting", function() {

    // Format text without an avatar lookup
    function formatQuote(text) {
      return format(text, {lookupAvatar: false});
    }

    it("can quote", function() {
      expect(formatQuote("[quote=\"eviltrout, post:1, topic:1\"]abc[/quote]")).
        toBe("</p><aside class='quote' data-post=\"1\" data-topic=\"1\" >\n  <div class='title'>\n    " +
             "<div class='quote-controls'></div>\n  \n  eviltrout\n  said:\n  </div>\n  <blockquote>abc</blockquote>\n</aside>\n<p>");
    });

    it("can nest quotes", function() {
      expect(formatQuote("[quote=\"eviltrout, post:1, topic:1\"]abc[quote=\"eviltrout, post:2, topic:2\"]nested[/quote][/quote]")).
        toBe("</p><aside class='quote' data-post=\"1\" data-topic=\"1\" >\n  <div class='title'>\n    <div " +
             "class='quote-controls'></div>\n  \n  eviltrout\n  said:\n  </div>\n  <blockquote>abc</p><aside " +
             "class='quote' data-post=\"2\" data-topic=\"2\" >\n  <div class='title'>\n    <div class='quote-" +
             "controls'></div>\n  \n  eviltrout\n  said:\n  </div>\n  <blockquote>nested</blockquote>\n</aside>\n<p></blockquote>\n</aside>\n<p>");
    });

    it("can handle more than one quote", function() {
      expect(formatQuote("before[quote=\"eviltrout, post:1, topic:1\"]first[/quote]middle[quote=\"eviltrout, post:2, topic:2\"]second[/quote]after")).
        toBe("before</p><aside class='quote' data-post=\"1\" data-topic=\"1\" >\n  <div class='title'>\n    <div class='quote-cont" +
             "rols'></div>\n  \n  eviltrout\n  said:\n  </div>\n  <blockquote>first</blockquote>\n</aside>\n<p>middle</p><aside cla" +
             "ss='quote' data-post=\"2\" data-topic=\"2\" >\n  <div class='title'>\n    <div class='quote-controls'></div>\n  \n  " +
             "eviltrout\n  said:\n  </div>\n  <blockquote>second</blockquote>\n</aside>\n<p>after");
    });

    describe("extractQuotes", function() {

      var extractQuotes = Discourse.BBCode.extractQuotes;

      it("returns an object a template renderer", function() {
        var q = "[quote=\"eviltrout, post:1, topic:2\"]hello[/quote]";
        var result = extractQuotes(q + " world");

        expect(result.text).toBe(md5(q) + "\n world");
        expect(result.template).not.toBe(null);
      });

    });

    describe("buildQuoteBBCode", function() {

      var build = Discourse.BBCode.buildQuoteBBCode;

      var post = Discourse.Post.create({
        cooked: "<p><b>lorem</b> ipsum</p>",
        username: "eviltrout",
        post_number: 1,
        topic_id: 2
      });

      it("returns an empty string when contents is undefined", function() {
        expect(build(post, undefined)).toBe("");
        expect(build(post, null)).toBe("");
        expect(build(post, "")).toBe("");
      });

      it("returns the quoted contents", function() {
        expect(build(post, "lorem")).toBe("[quote=\"eviltrout, post:1, topic:2\"]\nlorem\n[/quote]\n\n");
      });

      it("trims white spaces before & after the quoted contents", function() {
        expect(build(post, " lorem ")).toBe("[quote=\"eviltrout, post:1, topic:2\"]\nlorem\n[/quote]\n\n");
      });

      it("marks quotes as full when the quote is the full message", function() {
        expect(build(post, "lorem ipsum")).toBe("[quote=\"eviltrout, post:1, topic:2, full:true\"]\nlorem ipsum\n[/quote]\n\n");
      });

      it("keeps BBCode formatting", function() {
        expect(build(post, "**lorem** ipsum")).toBe("[quote=\"eviltrout, post:1, topic:2, full:true\"]\n**lorem** ipsum\n[/quote]\n\n");
      });

    });

  });

});
