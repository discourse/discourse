/*global waitsFor:true expect:true describe:true beforeEach:true it:true */
(function() {

  describe("Discourse.BBCode", function() {
    var format;
    format = Discourse.BBCode.format;
    describe('default replacer', function() {
      describe("simple tags", function() {
        it("bolds text", function() {
          return expect(format("[b]strong[/b]")).toBe("<span class='bbcode-b'>strong</span>");
        });
        it("italics text", function() {
          return expect(format("[i]emphasis[/i]")).toBe("<span class='bbcode-i'>emphasis</span>");
        });
        it("underlines text", function() {
          return expect(format("[u]underlined[/u]")).toBe("<span class='bbcode-u'>underlined</span>");
        });
        it("strikes-through text", function() {
          return expect(format("[s]strikethrough[/s]")).toBe("<span class='bbcode-s'>strikethrough</span>");
        });
        it("makes code into pre", function() {
          return expect(format("[code]\nx++\n[/code]")).toBe("<pre>\nx++\n</pre>");
        });
        it("supports spoiler tags", function() {
          return expect(format("[spoiler]it's a sled[/spoiler]")).toBe("<span class=\"spoiler\">it's a sled</span>");
        });
        it("links images", function() {
          return expect(format("[img]http://eviltrout.com/eviltrout.png[/img]")).toBe("<img src=\"http://eviltrout.com/eviltrout.png\">");
        });
        it("supports [url] without a title", function() {
          return expect(format("[url]http://bettercallsaul.com[/url]")).toBe("<a href=\"http://bettercallsaul.com\">http://bettercallsaul.com</a>");
        });
        return it("supports [email] without a title", function() {
          return expect(format("[email]eviltrout@mailinator.com[/email]")).toBe("<a href=\"mailto:eviltrout@mailinator.com\">eviltrout@mailinator.com</a>");
        });
      });
      describe("lists", function() {
        it("creates an ul", function() {
          return expect(format("[ul][li]option one[/li][/ul]")).toBe("<ul><li>option one</li></ul>");
        });
        return it("creates an ol", function() {
          return expect(format("[ol][li]option one[/li][/ol]")).toBe("<ol><li>option one</li></ol>");
        });
      });
      describe("color", function() {
        it("supports [color=] with a short hex value", function() {
          return expect(format("[color=#00f]blue[/color]")).toBe("<span style=\"color: #00f\">blue</span>");
        });
        it("supports [color=] with a long hex value", function() {
          return expect(format("[color=#ffff00]yellow[/color]")).toBe("<span style=\"color: #ffff00\">yellow</span>");
        });
        it("supports [color=] with an html color", function() {
          return expect(format("[color=red]red[/color]")).toBe("<span style=\"color: red\">red</span>");
        });
        return it("it performs a noop on invalid input", function() {
          return expect(format("[color=javascript:alert('wat')]noop[/color]")).toBe("noop");
        });
      });
      describe("tags with arguments", function() {
        it("supports [size=]", function() {
          return expect(format("[size=35]BIG[/size]")).toBe("<span class=\"bbcode-size-35\">BIG</span>");
        });
        it("supports [url] with a title", function() {
          return expect(format("[url=http://bettercallsaul.com]better call![/url]")).toBe("<a href=\"http://bettercallsaul.com\">better call!</a>");
        });
        return it("supports [email] with a title", function() {
          return expect(format("[email=eviltrout@mailinator.com]evil trout[/email]")).toBe("<a href=\"mailto:eviltrout@mailinator.com\">evil trout</a>");
        });
      });
      return describe("more complicated", function() {
        it("can nest tags", function() {
          return expect(format("[u][i]abc[/i][/u]")).toBe("<span class='bbcode-u'><span class='bbcode-i'>abc</span></span>");
        });
        return it("can bold two things on the same line", function() {
          return expect(format("[b]first[/b] [b]second[/b]")).toBe("<span class='bbcode-b'>first</span> <span class='bbcode-b'>second</span>");
        });
      });
    });
    return describe('email environment', function() {
      describe("simple tags", function() {
        it("bolds text", function() {
          return expect(format("[b]strong[/b]", {
            environment: 'email'
          })).toBe("<b>strong</b>");
        });
        it("italics text", function() {
          return expect(format("[i]emphasis[/i]", {
            environment: 'email'
          })).toBe("<i>emphasis</i>");
        });
        it("underlines text", function() {
          return expect(format("[u]underlined[/u]", {
            environment: 'email'
          })).toBe("<u>underlined</u>");
        });
        it("strikes-through text", function() {
          return expect(format("[s]strikethrough[/s]", {
            environment: 'email'
          })).toBe("<s>strikethrough</s>");
        });
        it("makes code into pre", function() {
          return expect(format("[code]\nx++\n[/code]", {
            environment: 'email'
          })).toBe("<pre>\nx++\n</pre>");
        });
        it("supports spoiler tags", function() {
          return expect(format("[spoiler]it's a sled[/spoiler]", {
            environment: 'email'
          })).toBe("<span style='background-color: #000'>it's a sled</span>");
        });
        it("links images", function() {
          return expect(format("[img]http://eviltrout.com/eviltrout.png[/img]", {
            environment: 'email'
          })).toBe("<img src=\"http://eviltrout.com/eviltrout.png\">");
        });
        it("supports [url] without a title", function() {
          return expect(format("[url]http://bettercallsaul.com[/url]", {
            environment: 'email'
          })).toBe("<a href=\"http://bettercallsaul.com\">http://bettercallsaul.com</a>");
        });
        return it("supports [email] without a title", function() {
          return expect(format("[email]eviltrout@mailinator.com[/email]", {
            environment: 'email'
          })).toBe("<a href=\"mailto:eviltrout@mailinator.com\">eviltrout@mailinator.com</a>");
        });
      });
      describe("lists", function() {
        it("creates an ul", function() {
          return expect(format("[ul][li]option one[/li][/ul]", {
            environment: 'email'
          })).toBe("<ul><li>option one</li></ul>");
        });
        return it("creates an ol", function() {
          return expect(format("[ol][li]option one[/li][/ol]", {
            environment: 'email'
          })).toBe("<ol><li>option one</li></ol>");
        });
      });
      describe("color", function() {
        it("supports [color=] with a short hex value", function() {
          return expect(format("[color=#00f]blue[/color]", {
            environment: 'email'
          })).toBe("<span style=\"color: #00f\">blue</span>");
        });
        it("supports [color=] with a long hex value", function() {
          return expect(format("[color=#ffff00]yellow[/color]", {
            environment: 'email'
          })).toBe("<span style=\"color: #ffff00\">yellow</span>");
        });
        it("supports [color=] with an html color", function() {
          return expect(format("[color=red]red[/color]", {
            environment: 'email'
          })).toBe("<span style=\"color: red\">red</span>");
        });
        return it("it performs a noop on invalid input", function() {
          return expect(format("[color=javascript:alert('wat')]noop[/color]", {
            environment: 'email'
          })).toBe("noop");
        });
      });
      return describe("tags with arguments", function() {
        it("supports [size=]", function() {
          return expect(format("[size=35]BIG[/size]", {
            environment: 'email'
          })).toBe("<span style=\"font-size: 35px\">BIG</span>");
        });
        it("supports [url] with a title", function() {
          return expect(format("[url=http://bettercallsaul.com]better call![/url]", {
            environment: 'email'
          })).toBe("<a href=\"http://bettercallsaul.com\">better call!</a>");
        });
        return it("supports [email] with a title", function() {
          return expect(format("[email=eviltrout@mailinator.com]evil trout[/email]", {
            environment: 'email'
          })).toBe("<a href=\"mailto:eviltrout@mailinator.com\">evil trout</a>");
        });
      });
    });
  });

}).call(this);
