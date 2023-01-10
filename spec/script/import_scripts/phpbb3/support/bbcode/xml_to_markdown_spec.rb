# frozen_string_literal: true

require Rails.root.join("script/import_scripts/phpbb3/support/bbcode/xml_to_markdown")

RSpec.describe ImportScripts::PhpBB3::BBCode::XmlToMarkdown do
  def convert(xml, opts = {})
    described_class.new(xml, opts).convert
  end

  it "converts unformatted text" do
    xml = "<t>unformatted text</t>"
    expect(convert(xml)).to eq("unformatted text")
  end

  it "converts nested formatting" do
    xml =
      "<r><I><s>[i]</s>this is italic<B><s>[b]</s> and bold<e>[/b]</e></B> text<e>[/i]</e></I></r>"
    expect(convert(xml)).to eq("_this is italic **and bold** text_")
  end

  context "with bold text" do
    it "converts bold text" do
      xml = "<r><B><s>[b]</s>this is bold text<e>[/b]</e></B></r>"
      expect(convert(xml)).to eq("**this is bold text**")
    end

    it "converts multi-line bold text" do
      xml = <<~XML
        <r><B><s>[b]</s>this is bold text<br/>
        on two lines<e>[/b]</e></B><br/>
        <br/>
        <B><s>[b]</s>this is bold text<br/>
        <br/>
        <br/>
        with two empty lines<e>[/b]</e></B></r>
      XML

      expect(convert(xml)).to eq(<<~MD.chomp)
        **this is bold text
        on two lines**

        **this is bold text\\
        \\
        \\
        with two empty lines**
      MD
    end

    it "ignores duplicate bold text" do
      xml = "<r><B><s>[b]</s><B><s>[b]</s>this is bold text<e>[/b]</e></B><e>[/b]</e></B></r>"
      expect(convert(xml)).to eq("**this is bold text**")
    end
  end

  context "with italic text" do
    it "converts italic text" do
      xml = "<r><I><s>[i]</s>this is italic text<e>[/i]</e></I></r>"
      expect(convert(xml)).to eq("_this is italic text_")
    end

    it "converts multi-line italic text" do
      xml = <<~XML
        <r><I><s>[i]</s>this is italic text<br/>
        on two lines<e>[/i]</e></I><br/>
        <br/>
        <I><s>[i]</s>this is italic text<br/>
        <br/>
        <br/>
        with two empty lines<e>[/i]</e></I></r>
      XML

      expect(convert(xml)).to eq(<<~MD.chomp)
        _this is italic text
        on two lines_

        _this is italic text\\
        \\
        \\
        with two empty lines_
      MD
    end

    it "ignores duplicate italic text" do
      xml = "<r><I><s>[i]</s><I><s>[i]</s>this is italic text<e>[/i]</e></I><e>[/i]</e></I></r>"
      expect(convert(xml)).to eq("_this is italic text_")
    end
  end

  context "with underlined text" do
    it "converts underlined text" do
      xml = "<r><U><s>[u]</s>this is underlined text<e>[/u]</e></U></r>"
      expect(convert(xml)).to eq("[u]this is underlined text[/u]")
    end

    it "converts multi-line underlined text" do
      xml = <<~XML
        <r><U><s>[u]</s>this is underlined text<br/>
        on two lines<e>[/u]</e></U><br/>
        <br/>
        <U><s>[u]</s>this is underlined text<br/>
        <br/>
        <br/>
        with two empty lines<e>[/u]</e></U></r>
      XML

      expect(convert(xml)).to eq(<<~MD.chomp)
        [u]this is underlined text
        on two lines[/u]

        [u]this is underlined text\\
        \\
        \\
        with two empty lines[/u]
      MD
    end

    it "ignores duplicate underlined text" do
      xml = "<r><U><s>[u]</s><U><s>[u]</s>this is underlined text<e>[/u]</e></U><e>[/u]</e></U></r>"
      expect(convert(xml)).to eq("[u]this is underlined text[/u]")
    end
  end

  context "with code blocks" do
    context "with inline code blocks enabled" do
      let(:opts) { { allow_inline_code: true } }

      it "converts single line code blocks" do
        xml = "<r><CODE><s>[code]</s>one line of code<e>[/code]</e></CODE></r>"
        expect(convert(xml, opts)).to eq("`one line of code`")
      end
    end

    context "with inline code blocks disabled" do
      it "converts single line code blocks" do
        xml = "<r>foo <CODE><s>[code]</s>some code<e>[/code]</e></CODE> bar</r>"

        expect(convert(xml)).to eq(<<~MD.chomp)
          foo

          ```text
          some code
          ```

          bar
        MD
      end
    end

    it "converts multi-line code blocks" do
      xml = <<~XML
        <r><CODE><s>[code]</s><i>
        </i> /\_/\
        ( o.o )
         &gt; ^ &lt;
         <e>[/code]</e></CODE></r>
      XML

      expect(convert(xml)).to eq(<<~MD.chomp)
        ```text
         /\_/\
        ( o.o )
         > ^ <
        ```
      MD
    end

    it "adds leading and trailing linebreaks to code blocks" do
      xml = <<~XML
        <r>text before code block<br/>

        <CODE><s>[code]</s><i>
        </i>foo

        bar
        <e>[/code]</e></CODE>

        text after code block</r>
      XML

      expect(convert(xml)).to eq(<<~MD.chomp)
        text before code block

        ```text
        foo

        bar
        ```

        text after code block
      MD
    end
  end

  context "with lists" do
    it "converts unordered lists" do
      xml = <<~XML
        <r><LIST><s>[list]</s>
        <LI><s>[*]</s>Red</LI>
        <LI><s>[*]</s>Blue</LI>
        <LI><s>[*]</s>Yellow</LI>
        <e>[/list]</e></LIST></r>
      XML

      expect(convert(xml)).to eq(<<~MD.chomp)
        * Red
        * Blue
        * Yellow
      MD
    end

    it "converts ordered lists" do
      xml = <<~XML
        <r><LIST type="decimal"><s>[list=1]</s>
        <LI><s>[*]</s>Go to the shops</LI>
        <LI><s>[*]</s>Buy a new computer</LI>
        <LI><s>[*]</s>Swear at computer when it crashes</LI>
        <e>[/list]</e></LIST></r>
      XML

      expect(convert(xml)).to eq(<<~MD.chomp)
        1. Go to the shops
        2. Buy a new computer
        3. Swear at computer when it crashes
      MD
    end

    it "converts all types of ordered lists into regular ordered lists" do
      xml = <<~XML
        <r><LIST type="upper-alpha"><s>[list=A]</s>
        <LI><s>[*]</s>The first possible answer</LI>
        <LI><s>[*]</s>The second possible answer</LI>
        <LI><s>[*]</s>The third possible answer</LI>
        <e>[/list]</e></LIST></r>
      XML

      expect(convert(xml)).to eq(<<~MD.chomp)
        1. The first possible answer
        2. The second possible answer
        3. The third possible answer
      MD
    end

    it "adds leading and trailing linebreaks to lists if needed" do
      xml = <<~XML
        <r>foo
        <LIST><s>[list]</s>
        <LI><s>[*]</s>Red</LI>
        <LI><s>[*]</s>Blue</LI>
        <LI><s>[*]</s>Yellow</LI>
        <e>[/list]</e></LIST>
        bar</r>
      XML

      expect(convert(xml)).to eq(<<~MD.chomp)
        foo

        * Red
        * Blue
        * Yellow

        bar
      MD
    end

    it "converts nested lists" do
      xml = <<~XML
        <r><LIST><s>[list]</s>
        <LI><s>[*]</s>Option 1
           <LIST><s>[list]</s>
              <LI><s>[*]</s>Option 1.1</LI>
              <LI><s>[*]</s>Option 1.2</LI>
           <e>[/list]</e></LIST></LI>
        <LI><s>[*]</s>Option 2
           <LIST><s>[list]</s>
              <LI><s>[*]</s>Option 2.1
                 <LIST type="decimal"><s>[list=1]</s>
                    <LI><s>[*]</s> Red</LI>
                    <LI><s>[*]</s> Blue</LI>
                 <e>[/list]</e></LIST></LI>
              <LI><s>[*]</s>Option 2.2</LI>
           <e>[/list]</e></LIST></LI>
        <e>[/list]</e></LIST></r>
      XML

      expect(convert(xml)).to eq(<<~MD.chomp)
        * Option 1
          * Option 1.1
          * Option 1.2
        * Option 2
          * Option 2.1
            1. Red
            2. Blue
          * Option 2.2
      MD
    end

    it "handles nested elements and linebreaks in list items" do
      xml = <<~XML
        <r><LIST><s>[list]</s><LI><s>[*]</s>some text <B><s>[b]</s><I><s>[i]</s>foo<e>[/i]</e></I><e>[/b]</e></B><br/>
        or <B><s>[b]</s><I><s>[i]</s>bar<e>[/i]</e></I><e>[/b]</e></B> more text</LI><e>[/list]</e></LIST></r>
      XML

      expect(convert(xml)).to eq(<<~MD.chomp)
        * some text **_foo_**
        or **_bar_** more text
      MD
    end
  end

  context "with images" do
    it "converts image" do
      xml = <<~XML
        <r><IMG src="https://example.com/foo.png"><s>[img]</s>
        <URL url="https://example.com/foo.png">
        <LINK_TEXT text="https://example.com/foo.png">https://example.com/foo.png</LINK_TEXT>
        </URL><e>[/img]</e></IMG></r>
      XML

      expect(convert(xml)).to eq("![](https://example.com/foo.png)")
    end

    it "converts image with link" do
      xml = <<~XML
        <r><URL url="https://example.com/"><s>[url=https://example.com/]</s>
        <IMG src="https://example.com/foo.png"><s>[img]</s>
        <LINK_TEXT text="https://example.com/foo.png">https://example.com/foo.png</LINK_TEXT>
        <e>[/img]</e></IMG><e>[/url]</e></URL></r>
      XML

      expect(convert(xml)).to eq("[![](https://example.com/foo.png)](https://example.com/)")
    end
  end

  context "with links" do
    it "converts links created without BBCode" do
      xml =
        '<r><URL url="https://en.wikipedia.org/wiki/Capybara">https://en.wikipedia.org/wiki/Capybara</URL></r>'
      expect(convert(xml)).to eq("https://en.wikipedia.org/wiki/Capybara")
    end

    it "converts links created with BBCode" do
      xml =
        '<r><URL url="https://en.wikipedia.org/wiki/Capybara"><s>[url]</s>https://en.wikipedia.org/wiki/Capybara<e>[/url]</e></URL></r>'
      expect(convert(xml)).to eq("https://en.wikipedia.org/wiki/Capybara")
    end

    it "converts links with link text" do
      xml =
        '<r><URL url="https://en.wikipedia.org/wiki/Capybara"><s>[url=https://en.wikipedia.org/wiki/Capybara]</s>Capybara<e>[/url]</e></URL></r>'
      expect(convert(xml)).to eq("[Capybara](https://en.wikipedia.org/wiki/Capybara)")
    end

    it "converts internal links" do
      opts = {
        url_replacement:
          lambda do |url|
            if url == "http://forum.example.com/viewtopic.php?f=2&t=2"
              "https://discuss.example.com/t/welcome-topic/18"
            end
          end,
      }

      xml =
        '<r><URL url="http://forum.example.com/viewtopic.php?f=2&amp;t=2"><LINK_TEXT text="viewtopic.php?f=2&amp;t=2">http://forum.example.com/viewtopic.php?f=2&amp;t=2</LINK_TEXT></URL></r>'
      expect(convert(xml, opts)).to eq("https://discuss.example.com/t/welcome-topic/18")
    end

    it "converts email links created without BBCode" do
      xml = '<r><EMAIL email="foo.bar@example.com">foo.bar@example.com</EMAIL></r>'
      expect(convert(xml)).to eq("<foo.bar@example.com>")
    end

    it "converts email links created with BBCode" do
      xml =
        '<r><EMAIL email="foo.bar@example.com"><s>[email]</s>foo.bar@example.com<e>[/email]</e></EMAIL></r>'
      expect(convert(xml)).to eq("<foo.bar@example.com>")
    end

    it "converts truncated, long links" do
      xml = <<~XML
        <r><URL url="http://answers.yahoo.com/question/index?qid=20070920134223AAkkPli">
        <s>[url]</s><LINK_TEXT text="http://answers.yahoo.com/question/index ... 223AAkkPli">
        http://answers.yahoo.com/question/index?qid=20070920134223AAkkPli</LINK_TEXT>
        <e>[/url]</e></URL></r>
      XML

      expect(convert(xml)).to eq(
        "http://answers.yahoo.com/question/index?qid=20070920134223AAkkPli",
      )
    end

    it "converts BBCodes inside link text" do
      xml = <<~XML
        <r><URL url="http://example.com"><s>[url=http://example.com]</s>
        <B><s>[b]</s>Hello <I><s>[i]</s>world<e>[/i]</e></I>!<e>[/b]</e></B>
        <e>[/url]</e></URL></r>
      XML

      expect(convert(xml)).to eq("[**Hello _world_!**](http://example.com)")
    end
  end

  context "with quotes" do
    it "converts simple quote" do
      xml = <<~XML
        <r><QUOTE><s>[quote]</s>Lorem<br/>
        ipsum<e>[/quote]</e></QUOTE></r>
      XML

      expect(convert(xml)).to eq(<<~MD.chomp)
        > Lorem
        > ipsum
      MD
    end

    it "converts quote with line breaks" do
      xml = <<~XML
        <r><QUOTE><s>[quote]</s>First paragraph<br/>
        <br/>
        Second paragraph<br/>
        <br/>
        <br/>
        Third paragraph<e>[/quote]</e></QUOTE></r>
      XML

      expect(convert(xml)).to eq(<<~MD.chomp)
        > First paragraph
        >
        > Second paragraph
        > \\
        > \\
        > Third paragraph
      MD
    end

    it "converts quote with line breaks and nested formatting" do
      xml = <<~XML
        <r><QUOTE><s>[quote]</s>
        <I><s>[i]</s>this is italic<br/>
        <B><s>[b]</s>and bold<br/>
        text<br/>
        <e>[/b]</e></B> on multiple<br/>
        <br/>
        <br/>
        lines<e>[/i]</e></I>
        <e>[/quote]</e></QUOTE></r>
      XML

      expect(convert(xml)).to eq(<<~MD.chomp)
        > _this is italic
        > **and bold
        > text**
        > on multiple\\
        > \\
        > \\
        > lines_
      MD
    end

    it "converts quote with author attribute" do
      xml =
        '<r><QUOTE author="Mr. Blobby"><s>[quote="Mr. Blobby"]</s>Lorem ipsum<e>[/quote]</e></QUOTE></r>'

      expect(convert(xml)).to eq(<<~MD.chomp)
        [quote="Mr. Blobby"]
        Lorem ipsum
        [/quote]
      MD
    end

    it "converts quote with author attribute and line breaks" do
      xml = <<~XML
        <r><QUOTE author="Mr. Blobby"><s>[quote="Mr. Blobby"]</s>First paragraph<br/>
        <br/>
        Second paragraph<br/>
        <br/>
        Third paragraph<e>[/quote]</e></QUOTE></r>
      XML

      expect(convert(xml)).to eq(<<~MD.chomp)
        [quote="Mr. Blobby"]
        First paragraph

        Second paragraph

        Third paragraph
        [/quote]
      MD
    end

    context "with user_id attribute" do
      let(:opts) do
        { username_from_user_id: lambda { |user_id| user_id == 48 ? "mr_blobby" : nil } }
      end

      it "uses the correct username when the user exists" do
        xml =
          '<r><QUOTE author="Mr. Blobby" user_id="48"><s>[quote="Mr. Blobby" user_id=48]</s>Lorem ipsum<e>[/quote]</e></QUOTE></r>'

        expect(convert(xml, opts)).to eq(<<~MD.chomp)
          [quote="mr_blobby"]
          Lorem ipsum
          [/quote]
        MD
      end

      it "uses the author name when the user does not exist" do
        xml =
          '<r><QUOTE author="Mr. Blobby" user_id="49"><s>[quote="Mr. Blobby" user_id=48]</s>Lorem ipsum<e>[/quote]</e></QUOTE></r>'

        expect(convert(xml, opts)).to eq(<<~MD.chomp)
          [quote="Mr. Blobby"]
          Lorem ipsum
          [/quote]
        MD
      end

      it "creates a blockquote when the user does not exist and the author is missing" do
        xml =
          '<r><QUOTE user_id="49"><s>[quote=user_id=48]</s>Lorem ipsum<e>[/quote]</e></QUOTE></r>'
        expect(convert(xml, opts)).to eq("> Lorem ipsum")
      end
    end

    context "with post_id attribute" do
      let(:opts) do
        {
          quoted_post_from_post_id:
            lambda do |post_id|
              { username: "mr_blobby", post_number: 3, topic_id: 951 } if post_id == 43
            end,
        }
      end

      it "uses information from the quoted post if the post exists" do
        xml = <<~XML
          <r><QUOTE author="Mr. Blobby" post_id="43" time="1534626128" user_id="48">
          <s>[quote="Mr. Blobby" post_id=43 time=1534626128 user_id=48]</s>Lorem ipsum<e>[/quote]</e>
          </QUOTE></r>
        XML

        expect(convert(xml, opts)).to eq(<<~MD.chomp)
          [quote="mr_blobby, post:3, topic:951"]
          Lorem ipsum
          [/quote]
        MD
      end

      it "uses other attributes when post doesn't exist" do
        xml = <<~XML
          <r><QUOTE author="Mr. Blobby" post_id="44" time="1534626128" user_id="48">
          <s>[quote="Mr. Blobby" post_id=44 time=1534626128 user_id=48]</s>Lorem ipsum<e>[/quote]</e>
          </QUOTE></r>
        XML

        expect(convert(xml, opts)).to eq(<<~MD.chomp)
          [quote="Mr. Blobby"]
          Lorem ipsum
          [/quote]
        MD
      end
    end

    it "converts nested quotes" do
      xml = <<~XML
        <r>Multiple nested quotes:<br/>

          <QUOTE author="user3">
            <s>[quote=user3]</s>
            <QUOTE author="user2">
              <s>[quote=user2]</s>
              <QUOTE author="user1">
                <s>[quote=user1]</s>
                <B><s>[b]</s>foo <I><s>[i]</s>and<e>[/i]</e></I> bar<e>[/b]</e></B>
                <e>[/quote]</e>
              </QUOTE>

              Lorem ipsum
              <e>[/quote]</e>
            </QUOTE>

            nested quotes
            <e>[/quote]</e>
          </QUOTE>

          Text after quotes.
        </r>
      XML

      expect(convert(xml)).to eq(<<~MD.chomp)
        Multiple nested quotes:

        [quote="user3"]
        [quote="user2"]
        [quote="user1"]
        **foo _and_ bar**
        [/quote]

        Lorem ipsum
        [/quote]

        nested quotes
        [/quote]

        Text after quotes.
      MD
    end
  end

  it "converts smilies" do
    opts = {
      smilie_to_emoji:
        lambda do |smilie|
          case smilie
          when ":D"
            ":smiley:"
          when ":eek:"
            ":astonished:"
          end
        end,
    }

    xml = "<r><E>:D</E> <E>:eek:</E></r>"
    expect(convert(xml, opts)).to eq(":smiley: :astonished:")
  end

  context "with attachments" do
    it "converts attachments" do
      opts = {
        upload_md_from_file:
          lambda do |filename, index|
            url =
              case index
              when 0
                "upload://hash2.png"
              when 1
                "upload://hash1.png"
              end

            "![#{filename}|231x231](#{url})"
          end,
      }

      xml = <<~XML
        <r>Multiple attachments:
        <ATTACHMENT filename="image1.png" index="1"><s>[attachment=1]</s>image1.png<e>[/attachment]</e></ATTACHMENT>
        This is an inline image.<br/>
        <br/>
        And another one:
        <ATTACHMENT filename="image2.png" index="0"><s>[attachment=0]</s>image2.png<e>[/attachment]</e></ATTACHMENT></r>
      XML

      expect(convert(xml, opts)).to eq(<<~MD.chomp)
        Multiple attachments:
        ![image1.png|231x231](upload://hash1.png)
        This is an inline image.

        And another one:
        ![image2.png|231x231](upload://hash2.png)
      MD
    end
  end

  context "with line breaks" do
    it "converts line breaks" do
      xml = <<~XML
      <t>Lorem ipsum dolor sit amet.<br/>
      <br/>
      Consetetur sadipscing elitr.<br/>
      <br/>
      <br/>
      Sed diam nonumy eirmod tempor.<br/>
      <br/>
      <br/>
      <br/>
      <br/>
      Invidunt ut labore et dolore.</t>
      XML

      expect(convert(xml)).to eq(<<~MD.chomp)
        Lorem ipsum dolor sit amet.

        Consetetur sadipscing elitr.
        \\
        \\
        Sed diam nonumy eirmod tempor.
        \\
        \\
        \\
        \\
        Invidunt ut labore et dolore.
      MD
    end

    it "uses hard linebreaks when tradition line breaks are enabled" do
      xml = <<~XML
      <t>Lorem ipsum dolor sit amet.<br/>
      Consetetur sadipscing elitr.<br/>
      <br/>
      Sed diam nonumy eirmod tempor.<br/>
      <br/>
      <br/>
      <br/>
      Invidunt ut labore et dolore.</t>
      XML

      expect(convert(xml, traditional_linebreaks: true)).to eq(<<~MD.chomp)
        Lorem ipsum dolor sit amet.\\
        Consetetur sadipscing elitr.\\
        \\
        Sed diam nonumy eirmod tempor.\\
        \\
        \\
        \\
        Invidunt ut labore et dolore.
      MD
    end

    it "uses <br> in front of block elements" do
      xml = <<~XML
        <r>text before 4 empty lines<br/>
        <br/>
        <br/>
        <br/>

        <CODE><s>[code]</s>some code<e>[/code]</e></CODE>
        text before 3 empty lines<br/>
        <br/>
        <br/>

        <LIST><s>[list]</s>
        <LI><s>[*]</s> item 1</LI>
        <LI><s>[*]</s> item 2</LI>
        <e>[/list]</e></LIST>
        text before 2 empty lines<br/>
        <br/>

        <LIST><s>[list]</s>
        <LI><s>[*]</s> item 1</LI>
        <LI><s>[*]</s> item 2</LI>
        <e>[/list]</e></LIST></r>
      XML

      expect(convert(xml)).to eq(<<~MD.chomp)
        text before 4 empty lines
        \\
        \\
        \\
        <br>
        ```text
        some code
        ```

        text before 3 empty lines
        \\
        \\
        <br>
        * item 1
        * item 2

        text before 2 empty lines
        \\
        <br>
        * item 1
        * item 2
      MD
    end
  end

  context "with whitespace" do
    it "doesn't strip whitespaces from inline tags" do
      xml = <<~XML
        <r>Lorem<B><s>[b]</s> ipsum <e>[/b]</e></B>dolor<br/>
        <I><s>[i]</s> sit <e>[/i]</e></I>amet,<br/>
        consetetur<B><s>[b]</s> sadipscing <e>[/b]</e></B></r>
      XML

      expect(convert(xml)).to eq(<<~MD.rstrip)
        Lorem **ipsum** dolor
        _sit_ amet,
        consetetur **sadipscing**
      MD
    end

    it "preserves whitespace between tags" do
      xml =
        "<r>foo <B><s>[b]</s>bold<e>[/b]</e></B> <I><s>[i]</s>italic<e>[/i]</e></I> <U><s>[u]</s>underlined<e>[/u]</e></U> bar</r>"
      expect(convert(xml)).to eq("foo **bold** _italic_ [u]underlined[/u] bar")
    end
  end

  context "with unknown element" do
    it "converts an unknown element right below the root element" do
      xml = "<r><UNKNOWN><s>[unknown]</s>foo<e>[/unknown]</e></UNKNOWN></r>"
      expect(convert(xml)).to eq("foo")
    end

    it "converts an unknown element inside a known element" do
      xml =
        "<r><B><s>[b]</s><UNKNOWN><s>[unknown]</s>bar<e>[/unknown]</e></UNKNOWN><e>[/b]</e></B></r>"
      expect(convert(xml)).to eq("**bar**")
    end
  end

  context "with font size" do
    it "converts sizes to either <small> or <big>" do
      xml = <<~XML
        <r><SIZE size="50"><s>[size=50]</s>very small<e>[/size]</e></SIZE><br/>
        <SIZE size="85"><s>[size=85]</s>small<e>[/size]</e></SIZE><br/>
        <SIZE size="150"><s>[size=150]</s>large<e>[/size]</e></SIZE><br/>
        <SIZE size="200"><s>[size=200]</s>very large<e>[/size]</e></SIZE></r>
      XML

      expect(convert(xml)).to eq(<<~MD.rstrip)
        <small>very small</small>
        <small>small</small>
        <big>large</big>
        <big>very large</big>
      MD
    end

    it "ignores invalid sizes" do
      xml = <<~XML
        <r><SIZE size="-50"><s>[size=-50]</s>negative number<e>[/size]</e></SIZE><br/>
        <SIZE size="0"><s>[size=0]</s>zero<e>[/size]</e></SIZE><br/>
        <SIZE size="300"><s>[size=300]</s>too large<e>[/size]</e></SIZE><br/>
        <SIZE size="abc"><s>[size=abc]</s>not a number<e>[/size]</e></SIZE><br/>
        <SIZE><s>[size]</s>no size<e>[/size]</e></SIZE></r>
      XML

      expect(convert(xml)).to eq(<<~MD.rstrip)
        negative number
        zero
        too large
        not a number
        no size
      MD
    end
  end
end
