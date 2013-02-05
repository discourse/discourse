describe "Discourse.BBCode", ->

  format = Discourse.BBCode.format

  describe 'default replacer', ->

    describe "simple tags", ->
      it "bolds text", ->
        expect(format("[b]strong[/b]")).toBe("<span class='bbcode-b'>strong</span>")

      it "italics text", ->
        expect(format("[i]emphasis[/i]")).toBe("<span class='bbcode-i'>emphasis</span>")

      it "underlines text", ->
        expect(format("[u]underlined[/u]")).toBe("<span class='bbcode-u'>underlined</span>")

      it "strikes-through text", ->
        expect(format("[s]strikethrough[/s]")).toBe("<span class='bbcode-s'>strikethrough</span>")

      it "makes code into pre", ->
        expect(format("[code]\nx++\n[/code]")).toBe("<pre>\nx++\n</pre>")

      it "supports spoiler tags", ->
        expect(format("[spoiler]it's a sled[/spoiler]")).toBe("<span class=\"spoiler\">it's a sled</span>")

      it "links images", ->
        expect(format("[img]http://eviltrout.com/eviltrout.png[/img]")).toBe("<img src=\"http://eviltrout.com/eviltrout.png\">")

      it "supports [url] without a title", ->
        expect(format("[url]http://bettercallsaul.com[/url]")).toBe("<a href=\"http://bettercallsaul.com\">http://bettercallsaul.com</a>")    

      it "supports [email] without a title", ->
        expect(format("[email]eviltrout@mailinator.com[/email]")).toBe("<a href=\"mailto:eviltrout@mailinator.com\">eviltrout@mailinator.com</a>")    

    describe "lists", ->
      it "creates an ul", ->
        expect(format("[ul][li]option one[/li][/ul]")).toBe("<ul><li>option one</li></ul>")

      it "creates an ol", ->
        expect(format("[ol][li]option one[/li][/ol]")).toBe("<ol><li>option one</li></ol>")


    describe "color", ->

      it "supports [color=] with a short hex value", ->
        expect(format("[color=#00f]blue[/color]")).toBe("<span style=\"color: #00f\">blue</span>")    

      it "supports [color=] with a long hex value", ->
        expect(format("[color=#ffff00]yellow[/color]")).toBe("<span style=\"color: #ffff00\">yellow</span>")

      it "supports [color=] with an html color", ->
        expect(format("[color=red]red[/color]")).toBe("<span style=\"color: red\">red</span>")      

      it "it performs a noop on invalid input", ->
        expect(format("[color=javascript:alert('wat')]noop[/color]")).toBe("noop")      

    describe "tags with arguments", ->

      it "supports [size=]", ->
        expect(format("[size=35]BIG[/size]")).toBe("<span class=\"bbcode-size-35\">BIG</span>")    

      it "supports [url] with a title", ->
        expect(format("[url=http://bettercallsaul.com]better call![/url]")).toBe("<a href=\"http://bettercallsaul.com\">better call!</a>")    

      it "supports [email] with a title", ->
        expect(format("[email=eviltrout@mailinator.com]evil trout[/email]")).toBe("<a href=\"mailto:eviltrout@mailinator.com\">evil trout</a>")    

    describe "more complicated", ->

      it "can nest tags", ->
        expect(format("[u][i]abc[/i][/u]")).toBe("<span class='bbcode-u'><span class='bbcode-i'>abc</span></span>")

      it "can bold two things on the same line", ->
        expect(format("[b]first[/b] [b]second[/b]")).toBe("<span class='bbcode-b'>first</span> <span class='bbcode-b'>second</span>")  

  describe 'email environment', ->

    describe "simple tags", ->
      it "bolds text", ->
        expect(format("[b]strong[/b]", environment: 'email')).toBe("<b>strong</b>")

      it "italics text", ->
        expect(format("[i]emphasis[/i]", environment: 'email')).toBe("<i>emphasis</i>")

      it "underlines text", ->
        expect(format("[u]underlined[/u]", environment: 'email')).toBe("<u>underlined</u>")

      it "strikes-through text", ->
        expect(format("[s]strikethrough[/s]", environment: 'email')).toBe("<s>strikethrough</s>")

      it "makes code into pre", ->
        expect(format("[code]\nx++\n[/code]", environment: 'email')).toBe("<pre>\nx++\n</pre>")

      it "supports spoiler tags", ->
        expect(format("[spoiler]it's a sled[/spoiler]", environment: 'email')).toBe("<span style='background-color: #000'>it's a sled</span>")

      it "links images", ->
        expect(format("[img]http://eviltrout.com/eviltrout.png[/img]", environment: 'email')).toBe("<img src=\"http://eviltrout.com/eviltrout.png\">")

      it "supports [url] without a title", ->
        expect(format("[url]http://bettercallsaul.com[/url]", environment: 'email')).toBe("<a href=\"http://bettercallsaul.com\">http://bettercallsaul.com</a>")    

      it "supports [email] without a title", ->
        expect(format("[email]eviltrout@mailinator.com[/email]", environment: 'email')).toBe("<a href=\"mailto:eviltrout@mailinator.com\">eviltrout@mailinator.com</a>")    

    describe "lists", ->
      it "creates an ul", ->
        expect(format("[ul][li]option one[/li][/ul]", environment: 'email')).toBe("<ul><li>option one</li></ul>")

      it "creates an ol", ->
        expect(format("[ol][li]option one[/li][/ol]", environment: 'email')).toBe("<ol><li>option one</li></ol>")


    describe "color", ->

      it "supports [color=] with a short hex value", ->
        expect(format("[color=#00f]blue[/color]", environment: 'email')).toBe("<span style=\"color: #00f\">blue</span>")    

      it "supports [color=] with a long hex value", ->
        expect(format("[color=#ffff00]yellow[/color]", environment: 'email')).toBe("<span style=\"color: #ffff00\">yellow</span>")

      it "supports [color=] with an html color", ->
        expect(format("[color=red]red[/color]", environment: 'email')).toBe("<span style=\"color: red\">red</span>")      

      it "it performs a noop on invalid input", ->
        expect(format("[color=javascript:alert('wat')]noop[/color]", environment: 'email')).toBe("noop")      

    describe "tags with arguments", ->

      it "supports [size=]", ->
        expect(format("[size=35]BIG[/size]", environment: 'email')).toBe("<span style=\"font-size: 35px\">BIG</span>")    

      it "supports [url] with a title", ->
        expect(format("[url=http://bettercallsaul.com]better call![/url]", environment: 'email')).toBe("<a href=\"http://bettercallsaul.com\">better call!</a>")    

      it "supports [email] with a title", ->
        expect(format("[email=eviltrout@mailinator.com]evil trout[/email]", environment: 'email')).toBe("<a href=\"mailto:eviltrout@mailinator.com\">evil trout</a>")    

