/*global waitsFor:true expect:true describe:true beforeEach:true it:true */

describe("Discourse.BBCode", function() {

  var format = Discourse.BBCode.format;

  describe('default replacer', function() {

    describe("simple tags", function() {

      it("bolds text", function() {
        expect(format("[b]strong[/b]")).toBe("<span class='bbcode-b'>strong</span>");
      });

      it("italics text", function() {
        expect(format("[i]emphasis[/i]")).toBe("<span class='bbcode-i'>emphasis</span>");
      });

      it("underlines text", function() {
        expect(format("[u]underlined[/u]")).toBe("<span class='bbcode-u'>underlined</span>");
      });

      it("strikes-through text", function() {
        expect(format("[s]strikethrough[/s]")).toBe("<span class='bbcode-s'>strikethrough</span>");
      });

      it("makes code into pre", function() {
        expect(format("[code]\nx++\n[/code]")).toBe("<pre>\nx++\n</pre>");
      });

      it("supports spoiler tags", function() {
        expect(format("[spoiler]it's a sled[/spoiler]")).toBe("<span class=\"spoiler\">it's a sled</span>");
      });

      it("links images", function() {
        expect(format("[img]http://eviltrout.com/eviltrout.png[/img]")).toBe("<img src=\"http://eviltrout.com/eviltrout.png\">");
      });

      it("supports [url] without a title", function() {
        expect(format("[url]http://bettercallsaul.com[/url]")).toBe("<a href=\"http://bettercallsaul.com\">http://bettercallsaul.com</a>");
      });

      it("supports [email] without a title", function() {
        expect(format("[email]eviltrout@mailinator.com[/email]")).toBe("<a href=\"mailto:eviltrout@mailinator.com\">eviltrout@mailinator.com</a>");
      });

    });

    describe("lists", function() {

      it("creates an ul", function() {
        expect(format("[ul][li]option one[/li][/ul]")).toBe("<ul><li>option one</li></ul>");
      });

      it("creates an ol", function() {
        expect(format("[ol][li]option one[/li][/ol]")).toBe("<ol><li>option one</li></ol>");
      });

    });

    describe("color", function() {

      it("supports [color=] with a short hex value", function() {
        expect(format("[color=#00f]blue[/color]")).toBe("<span style=\"color: #00f\">blue</span>");
      });

      it("supports [color=] with a long hex value", function() {
        expect(format("[color=#ffff00]yellow[/color]")).toBe("<span style=\"color: #ffff00\">yellow</span>");
      });

      it("supports [color=] with an html color", function() {
        expect(format("[color=red]red[/color]")).toBe("<span style=\"color: red\">red</span>");
      });

      it("it performs a noop on invalid input", function() {
        expect(format("[color=javascript:alert('wat')]noop[/color]")).toBe("noop");
      });

    });

    describe("tags with arguments", function() {

      it("supports [size=]", function() {
        expect(format("[size=35]BIG[/size]")).toBe("<span class=\"bbcode-size-35\">BIG</span>");
      });

      it("supports [url] with a title", function() {
        expect(format("[url=http://bettercallsaul.com]better call![/url]")).toBe("<a href=\"http://bettercallsaul.com\">better call!</a>");
      });

      it("supports [email] with a title", function() {
        expect(format("[email=eviltrout@mailinator.com]evil trout[/email]")).toBe("<a href=\"mailto:eviltrout@mailinator.com\">evil trout</a>");
      });

    });

    describe("more complicated", function() {

      it("can nest tags", function() {
        expect(format("[u][i]abc[/i][/u]")).toBe("<span class='bbcode-u'><span class='bbcode-i'>abc</span></span>");
      });

      it("can bold two things on the same line", function() {
        expect(format("[b]first[/b] [b]second[/b]")).toBe("<span class='bbcode-b'>first</span> <span class='bbcode-b'>second</span>");
      });

    });

  });

  describe('email environment', function() {

    describe("simple tags", function() {

      it("bolds text", function() {
        expect(format("[b]strong[/b]", { environment: 'email' })).toBe("<b>strong</b>");
      });

      it("italics text", function() {
        expect(format("[i]emphasis[/i]", { environment: 'email' })).toBe("<i>emphasis</i>");
      });

      it("underlines text", function() {
        expect(format("[u]underlined[/u]", { environment: 'email' })).toBe("<u>underlined</u>");
      });

      it("strikes-through text", function() {
        expect(format("[s]strikethrough[/s]", { environment: 'email' })).toBe("<s>strikethrough</s>");
      });

      it("makes code into pre", function() {
        expect(format("[code]\nx++\n[/code]", { environment: 'email' })).toBe("<pre>\nx++\n</pre>");
      });

      it("supports spoiler tags", function() {
        expect(format("[spoiler]it's a sled[/spoiler]", { environment: 'email' })).toBe("<span style='background-color: #000'>it's a sled</span>");
      });

      it("links images", function() {
        expect(format("[img]http://eviltrout.com/eviltrout.png[/img]", { environment: 'email' })).toBe("<img src=\"http://eviltrout.com/eviltrout.png\">");
      });

      it("supports [url] without a title", function() {
        expect(format("[url]http://bettercallsaul.com[/url]", { environment: 'email' })).toBe("<a href=\"http://bettercallsaul.com\">http://bettercallsaul.com</a>");
      });

      it("supports [email] without a title", function() {
        expect(format("[email]eviltrout@mailinator.com[/email]", { environment: 'email' })).toBe("<a href=\"mailto:eviltrout@mailinator.com\">eviltrout@mailinator.com</a>");
      });

    });

    describe("lists", function() {

      it("creates an ul", function() {
        expect(format("[ul][li]option one[/li][/ul]", { environment: 'email' })).toBe("<ul><li>option one</li></ul>");
      });

      it("creates an ol", function() {
        expect(format("[ol][li]option one[/li][/ol]", { environment: 'email' })).toBe("<ol><li>option one</li></ol>");
      });

    });

    describe("color", function() {

      it("supports [color=] with a short hex value", function() {
        expect(format("[color=#00f]blue[/color]", { environment: 'email' })).toBe("<span style=\"color: #00f\">blue</span>");
      });

      it("supports [color=] with a long hex value", function() {
        expect(format("[color=#ffff00]yellow[/color]", { environment: 'email' })).toBe("<span style=\"color: #ffff00\">yellow</span>");
      });

      it("supports [color=] with an html color", function() {
        expect(format("[color=red]red[/color]", { environment: 'email' })).toBe("<span style=\"color: red\">red</span>");
      });

      it("it performs a noop on invalid input", function() {
        expect(format("[color=javascript:alert('wat')]noop[/color]", { environment: 'email' })).toBe("noop");
      });

    });

    describe("tags with arguments", function() {

      it("supports [size=]", function() {
        expect(format("[size=35]BIG[/size]", { environment: 'email' })).toBe("<span style=\"font-size: 35px\">BIG</span>");
      });

      it("supports [url] with a title", function() {
        expect(format("[url=http://bettercallsaul.com]better call![/url]", { environment: 'email' })).toBe("<a href=\"http://bettercallsaul.com\">better call!</a>");
      });

      it("supports [email] with a title", function() {
        expect(format("[email=eviltrout@mailinator.com]evil trout[/email]", { environment: 'email' })).toBe("<a href=\"mailto:eviltrout@mailinator.com\">evil trout</a>");
      });

    });

  });

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
