# frozen_string_literal: true

require "html_to_markdown"

RSpec.describe HtmlToMarkdown do
  def html_to_markdown(html, opts = {})
    HtmlToMarkdown.new(html, opts).to_markdown
  end

  it "remove whitespaces" do
    html = <<-HTML
      <div dir="auto">Hello,
        <div dir="auto"><br></div>
        <div dir="auto">&nbsp; &nbsp; This is the 1st paragraph.&nbsp; &nbsp; </div>
        <div dir="auto"><br></div>
        <div dir="auto">
          &nbsp; &nbsp; &nbsp; &nbsp; This is another paragraph
        </div>
      </div>
    HTML

    expect(html_to_markdown(html)).to eq(
      "Hello,\n\nThis is the 1st paragraph.\n\nThis is another paragraph",
    )

    html = <<~HTML
      <body text="#000000" bgcolor="#FFFFFF">
          <p>Let me see if it happens by answering your message through
            Thunderbird.</p>
          <p>Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1
            Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1
            Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1
            Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1
            Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1
            Long sentence 1
          </p>
      </body>
    HTML

    markdown = <<~MD
      Let me see if it happens by answering your message through Thunderbird.

      Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1 Long sentence 1
    MD

    expect(html_to_markdown(html)).to eq(markdown.strip)

    html = <<~HTML
      <p>    This     post
            has             lots<br>           of
                  space
      </p>
      <pre>    This     space    was   left untouched     !</pre>
    HTML

    markdown = <<~MD
      This post has lots
      of space

      ```
          This     space    was   left untouched     !
      ```
    MD

    expect(html_to_markdown(html)).to eq(markdown.strip)
  end

  it "removes tags that aren't allowed" do
    html = <<~HTML
      <custom>Text withing custom <span>tag</span></custom>
      <div>Text within allowed tag</div>
    HTML

    expect(html_to_markdown(html)).to eq("Text within allowed tag")
  end

  it "allows additional tags that can be consumed by subclasses" do
    class ExtendedHtmlToMarkdown < HtmlToMarkdown
      def to_markdown
        yield @doc
        super
      end
    end

    html = <<~HTML
      <custom-image image-id="42">Image text</custom-image>
      <div>Text within allowed tag</div>
    HTML

    md =
      ExtendedHtmlToMarkdown
        .new(html)
        .to_markdown { |doc| expect(doc.css("custom-image")).to be_empty }
    expect(md).to eq("Text within allowed tag")

    md =
      ExtendedHtmlToMarkdown
        .new(html, { additional_allowed_tags: ["custom-image"] })
        .to_markdown do |doc|
          doc.css("custom-image").each { |img| img.replace("Image #{img["image-id"]}") }
        end
    expect(md).to eq("Image 42\nText within allowed tag")
  end

  it "doesn't error on non-inline elements like (aside, section)" do
    html = <<~HTML
      <aside class="quote no-group">
      <blockquote>
      <p>Hello,<br>is it me you're looking for?</p>
      </blockquote>
      <br>
      </aside>
    HTML

    markdown = <<~MD
      > Hello,
      > is it me you're looking for?
    MD

    expect(html_to_markdown(html)).to eq(markdown.strip)
  end

  it "skips hidden tags" do
    expect(html_to_markdown("<p>Hello <span hidden>cruel </span>World!</p>")).to eq("Hello World!")
  end

  it "converts <strong>" do
    expect(html_to_markdown("<strong>Strong</strong>")).to eq("**Strong**")
    expect(html_to_markdown("<strong>Str*ng</strong>")).to eq("__Str*ng__")
  end

  it "converts <b>" do
    expect(html_to_markdown("<b>Bold</b>")).to eq("**Bold**")
    expect(html_to_markdown("<b>B*ld</b>")).to eq("__B*ld__")

    html = <<~HTML
      Before
      <p><b>Bold
      <br>
      <br>
      </b>
      </p>
      After
    HTML
    expect(html_to_markdown(html)).to eq("Before\n\n**Bold**\n\nAfter")
  end

  it "converts <em>" do
    expect(html_to_markdown("<em>Emphasis</em>")).to eq("*Emphasis*")
    expect(html_to_markdown("<em>Emph*sis</em>")).to eq("_Emph*sis_")
  end

  it "converts <i>" do
    expect(html_to_markdown("<i>Italic</i>")).to eq("*Italic*")
    expect(html_to_markdown("<i>It*lic</i>")).to eq("_It*lic_")
  end

  it "converts <a>" do
    expect(html_to_markdown(%Q{<a href="https://www.discourse.org">Discourse</a>})).to eq(
      "[Discourse](https://www.discourse.org)",
    )
  end

  it "supports SiteSetting.allowed_href_schemes" do
    SiteSetting.allowed_href_schemes = "tel|steam"
    expect(html_to_markdown(%Q{<a href="steam://store/48000">LIMBO</a>})).to eq(
      "[LIMBO](steam://store/48000)",
    )
  end

  it "removes empty & invalid <a>" do
    expect(html_to_markdown("<a>Discourse</a>")).to eq("Discourse")
    expect(html_to_markdown(%Q{<a href="">Discourse</a>})).to eq("Discourse")
    expect(html_to_markdown(%Q{<a href="foo.bar">Discourse</a>})).to eq("Discourse")
  end

  HTML_WITH_IMG = %Q{<img src="https://www.discourse.org/logo.svg" alt="Discourse Logo">}
  HTML_WITH_CID_IMG = %Q{<img src="cid:ii_1525434659ddb4cb" title="Discourse Logo">}

  it "converts <img>" do
    expect(html_to_markdown(HTML_WITH_IMG)).to eq(
      "![Discourse Logo](https://www.discourse.org/logo.svg)",
    )
  end

  it "keeps <img> with 'keep_img_tags'" do
    expect(html_to_markdown(HTML_WITH_IMG, keep_img_tags: true)).to eq(HTML_WITH_IMG)
  end

  it "removes newlines from img alt text" do
    html_with_alt_newlines =
      %Q{<img src="https://www.discourse.org/logo.svg" alt="Discourse\n\nLogo">}
    expect(html_to_markdown(html_with_alt_newlines)).to eq(
      "![Discourse Logo](https://www.discourse.org/logo.svg)",
    )
  end

  it "removes empty & invalid <img>" do
    expect(html_to_markdown("<img>")).to eq("")
    expect(html_to_markdown(%Q{<img src="">})).to eq("")
    expect(html_to_markdown(%Q{<img src="foo.bar">})).to eq("")
  end

  it "keeps <img> with src='cid:' with 'keep_cid_imgs'" do
    expect(html_to_markdown(HTML_WITH_CID_IMG, keep_cid_imgs: true)).to eq(HTML_WITH_CID_IMG)
  end

  it "removes newlines from img alt text with cid images" do
    html_with_cid_alt_newlines = %Q{<img src="cid:ii_1525434659ddb4cb" title="Discourse\n\nLogo">}
    expect(html_to_markdown(html_with_cid_alt_newlines, keep_cid_imgs: true)).to eq(
      %Q{<img src="cid:ii_1525434659ddb4cb" title="Discourse Logo">},
    )
  end

  it "skips hidden <img>" do
    expect(html_to_markdown(%Q{<img src="https://www.discourse.org/logo.svg" width=0>})).to eq("")
    expect(html_to_markdown(%Q{<img src="https://www.discourse.org/logo.svg" height="0">})).to eq(
      "",
    )
  end

  it "supports width/height on <img>" do
    expect(html_to_markdown(%Q{<img src="https://www.discourse.org/logo.svg" height=100>})).to eq(
      "![](https://www.discourse.org/logo.svg)",
    )
    expect(html_to_markdown(%Q{<img src="https://www.discourse.org/logo.svg" width=200>})).to eq(
      "![](https://www.discourse.org/logo.svg)",
    )
    expect(
      html_to_markdown(%Q{<img src="https://www.discourse.org/logo.svg" height=100 width=200>}),
    ).to eq("![|200x100](https://www.discourse.org/logo.svg)")
  end

  (1..6).each do |n|
    it "converts <h#{n}>" do
      expect(html_to_markdown("<h#{n}>Header #{n}</h#{n}>")).to eq("#" * n + " Header #{n}")
    end
  end

  it "converts <br>" do
    expect(html_to_markdown("Before<br>Inside<br>After")).to eq("Before\nInside\nAfter")
  end

  it "skips <br> inside <p> if next character is \n" do
    expect(html_to_markdown("<p>Before<br>\nInside<br>After</p>")).to eq("Before\nInside\nAfter")
  end

  it "converts <hr>" do
    expect(html_to_markdown("Before<hr>Inside<hr>After")).to eq(
      "Before\n\n---\n\nInside\n\n---\n\nAfter",
    )
  end

  it "converts <tt>" do
    expect(html_to_markdown("<tt>Teletype</tt>")).to eq("`Teletype`")
  end

  it "converts <code>" do
    expect(html_to_markdown("<code>Code</code>")).to eq("`Code`")
  end

  describe "when HTML is used within Markdown" do
    HtmlToMarkdown::ALLOWED.each do |tag|
      it "keeps mandatory HTML entities in text of <#{tag}>" do
        expect(html_to_markdown("<#{tag}>Less than: &lt;</#{tag}>")).to eq(
          "<#{tag}>Less than: &lt;</#{tag}>",
        )
        expect(html_to_markdown("<#{tag}>Greater than: &gt;")).to eq(
          "<#{tag}>Greater than: &gt;</#{tag}>",
        )
        expect(html_to_markdown("<#{tag}>Ampersand: &amp;")).to eq(
          "<#{tag}>Ampersand: &amp;</#{tag}>",
        )

        expect(html_to_markdown("<#{tag}>Double Quote: &quot;</#{tag}>")).to eq(
          "<#{tag}>Double Quote: \"</#{tag}>",
        )
        expect(html_to_markdown("<#{tag}>Single Quote: &apos;</#{tag}>")).to eq(
          "<#{tag}>Single Quote: '</#{tag}>",
        )
        expect(html_to_markdown("<#{tag}>Copyright Symbol: &copy;</#{tag}>")).to eq(
          "<#{tag}>Copyright Symbol: ©</#{tag}>",
        )
        expect(html_to_markdown("<#{tag}>Euro Symbol: &euro;</#{tag}>")).to eq(
          "<#{tag}>Euro Symbol: €</#{tag}>",
        )
      end
    end
  end

  it "supports <ins>" do
    expect(html_to_markdown("This is an <ins>insertion</ins>")).to eq(
      "This is an <ins>insertion</ins>",
    )
  end

  it "supports <del>" do
    expect(html_to_markdown("This is a <del>deletion</del>")).to eq("This is a <del>deletion</del>")
  end

  it "supports <sub>" do
    expect(html_to_markdown("H<sub>2</sub>O")).to eq("H<sub>2</sub>O")
  end

  it "supports <mark>" do
    expect(html_to_markdown("<mark>This is highlighted!</mark>")).to eq(
      "<mark>This is highlighted!</mark>",
    )
  end

  it "supports <sup>" do
    expect(html_to_markdown("<sup>Super Script!</sup>")).to eq("<sup>Super Script!</sup>")
  end

  it "supports <small>" do
    expect(html_to_markdown("<small>Small</small>")).to eq("<small>Small</small>")
    expect(html_to_markdown("<mark><small>Small</small></mark>")).to eq(
      "<mark><small>Small</small></mark>",
    )
    expect(html_to_markdown("<strong><small>Small</small></strong>")).to eq(
      "**<small>Small</small>**",
    )
    expect(html_to_markdown("<small><strong>&lt;small&gt;</strong></small>")).to eq(
      "<small>**&lt;small&gt;**</small>",
    )
  end

  it "supports <big>" do
    expect(html_to_markdown("<big>Big</big>")).to eq("<big>Big</big>")
    expect(html_to_markdown("<big>&lt;big&gt;</big>")).to eq("<big>&lt;big&gt;</big>")
  end

  it "supports <kbd>" do
    expect(html_to_markdown("<kbd>CTRL</kbd>+<kbd>C</kbd>")).to eq("<kbd>CTRL</kbd>+<kbd>C</kbd>")
    expect(html_to_markdown("<kbd>&lt;</kbd>")).to eq("<kbd>&lt;</kbd>")
  end

  it "supports <abbr>" do
    expect(
      html_to_markdown(%Q{<abbr title="Civilized Discourse Construction Kit, Inc.">CDCK</abbr>}),
    ).to eq(%Q{<abbr title="Civilized Discourse Construction Kit, Inc.">CDCK</abbr>})

    expect(
      html_to_markdown(
        %Q{<abbr title="&quot;abbr&quot;: The Abbreviation element">&lt;abbr&gt;</abbr>},
      ),
    ).to eq(%Q{<abbr title="&quot;abbr&quot;: The Abbreviation element">&lt;abbr&gt;</abbr>})
  end

  it "supports <s>" do
    expect(html_to_markdown("<s>Strike Through</s>")).to eq("~~Strike Through~~")
  end

  it "supports <strike>" do
    expect(html_to_markdown("<strike>Strike Through</strike>")).to eq("~~Strike Through~~")
  end

  it "supports <blockquote>" do
    expect(html_to_markdown("<blockquote>Quote</blockquote>")).to eq("> Quote")
  end

  it "supports <ul>" do
    expect(html_to_markdown("<ul><li>🍏</li><li>🍐</li><li>🍌</li></ul>")).to eq("- 🍏\n- 🍐\n- 🍌")
    expect(html_to_markdown("<ul>\n<li>🍏</li>\n<li>🍐</li>\n<li>🍌</li>\n</ul>")).to eq(
      "- 🍏\n- 🍐\n- 🍌",
    )
  end

  it "supports <ol>" do
    expect(html_to_markdown("<ol><li>🍆</li><li>🍅</li><li>🍄</li></ol>")).to eq("1. 🍆\n1. 🍅\n1. 🍄")
  end

  it "supports <p> inside <li>" do
    expect(html_to_markdown("<ul><li><p>🍏</p></li><li><p>🍐</p></li><li><p>🍌</p></li></ul>")).to eq(
      "- 🍏\n\n- 🍐\n\n- 🍌",
    )
  end

  it "supports <ul> inside <ul>" do
    expect(html_to_markdown(<<-HTML)).to eq(
      <ul>
        <li>Fruits
            <ul>
                <li>🍏</li>
                <li>🍐</li>
                <li>🍌</li>
            </ul>
        </li>
        <li>Vegetables
            <ul>
                <li>🍆</li>
                <li>🍅</li>
                <li>🍄</li>
            </ul>
        </li>
      </ul>
    HTML
      "- Fruits\n  - 🍏\n  - 🍐\n  - 🍌\n- Vegetables\n  - 🍆\n  - 🍅\n  - 🍄",
    )
  end

  it "supports bare <li>" do
    expect(html_to_markdown("<li>I'm alone</li>")).to eq("- I'm alone")
  end

  it "supports <pre>" do
    expect(html_to_markdown("<pre>var foo = 'bar';</pre>")).to eq("```\nvar foo = 'bar';\n```")
    expect(html_to_markdown("<pre><code>var foo = 'bar';</code></pre>")).to eq(
      "```\nvar foo = 'bar';\n```",
    )
    expect(
      html_to_markdown(%Q{<pre><code class="lang-javascript">var foo = 'bar';</code></pre>}),
    ).to eq("```javascript\nvar foo = 'bar';\n```")
    expect(
      html_to_markdown(
        "<pre>    function f() {\n        console.log('Hello world!');\n    }</pre>",
      ),
    ).to eq("```\n    function f() {\n        console.log('Hello world!');\n    }\n```")

    html = <<~HTML
      <pre data-code-wrap="plaintext"><code class="lang-plaintext">Reported-and-tested-by: A &lt;a@example.com&gt;
      Reviewed-by: B &lt;b@example.com&gt;</code></pre>
    HTML
    md = <<~MD
      ```plaintext
      Reported-and-tested-by: A <a@example.com>
      Reviewed-by: B <b@example.com>
      ```
    MD
    expect(html_to_markdown(html)).to eq(md.strip)
  end

  it "supports <pre> inside <blockquote>" do
    expect(
      html_to_markdown("<blockquote><pre><code>var foo = 'bar';</code></pre></blockquote>"),
    ).to eq("> ```\n> var foo = 'bar';\n> ```")
  end

  it "works" do
    expect(
      html_to_markdown(
        "<ul><li><p>A list item with a blockquote:</p><blockquote><p>This is a <strong>blockquote</strong><br>inside a list item.</p></blockquote></li></ul>",
      ),
    ).to eq(
      "- A list item with a blockquote:\n\n  > This is a **blockquote**\n  > inside a list item.",
    )
  end

  it "supports html document" do
    expect(html_to_markdown("<html><body>Hello<div>World</div></body></html>")).to eq(
      "Hello\nWorld",
    )
  end

  it "handles <p>" do
    expect(html_to_markdown("<p>1st paragraph</p><p>2nd paragraph</p>")).to eq(
      "1st paragraph\n\n2nd paragraph",
    )
    expect(
      html_to_markdown(
        "<body><p>1st paragraph</p>\n    <p>    2nd paragraph\n    2nd paragraph</p>\n<p>3rd paragraph</p></body>",
      ),
    ).to eq("1st paragraph\n\n2nd paragraph 2nd paragraph\n\n3rd paragraph")
  end

  it "handles <div>" do
    expect(html_to_markdown("<div>1st div</div><div>2nd div</div>")).to eq("1st div\n2nd div")
  end

  it "swallows <span>" do
    expect(html_to_markdown("<span>Span</span>")).to eq("Span")
  end

  it "swallows <u>" do
    expect(html_to_markdown("<u>Underline</u>")).to eq("Underline")
  end

  it "swallows <center>" do
    expect(html_to_markdown("<center>Centered</center>")).to eq("Centered")
  end

  it "removes <script>" do
    expect(html_to_markdown("<script>var foo = 'bar'</script>")).to eq("")
  end

  it "removes <style>" do
    expect(html_to_markdown("<style>* { margin: 0 }</style>")).to eq("")
  end

  it "handles <p> and <div> within <span>" do
    html = "<div>1st paragraph<span><div>2nd paragraph</div><p>3rd paragraph</p></span></div>"
    expect(html_to_markdown(html)).to eq("1st paragraph\n2nd paragraph\n\n3rd paragraph")
  end

  it "handles <p> and <div> within <font>" do
    html =
      "<font>1st paragraph<br><span>2nd paragraph</span><div>3rd paragraph</div><p>4th paragraph</p></font>"
    expect(html_to_markdown(html)).to eq(
      "1st paragraph\n2nd paragraph\n3rd paragraph\n\n4th paragraph",
    )
  end

  context "with an oddly placed <br>" do
    it "handles <strong>" do
      expect(html_to_markdown("Hello <strong><br>Bold</strong> World")).to eq(
        "Hello\n**Bold** World",
      )
      expect(html_to_markdown("Hello <strong>Bold<br></strong> World")).to eq(
        "Hello **Bold**\nWorld",
      )
      expect(html_to_markdown("Hello <strong>Bold<br>text</strong> World")).to eq(
        "Hello **Bold**\n**text** World",
      )
    end

    it "handles <em>" do
      expect(html_to_markdown("Hello <em><br>Italic</em> World")).to eq("Hello\n*Italic* World")
      expect(html_to_markdown("Hello <em>Italic<br></em> World")).to eq("Hello *Italic*\nWorld")
      expect(html_to_markdown("Hello <em>Italic<br>text</em> World")).to eq(
        "Hello *Italic*\n*text* World",
      )
    end

    it "works" do
      expect(html_to_markdown("<div>A <b> B <i> C <br> D </i> E <br> F </b> G</div>")).to eq(
        "A __B *C*__\n__*D* E__\n**F** G",
      )
    end
  end

  context "with an empty tag" do
    it "handles <strong>" do
      expect(html_to_markdown("<strong></strong>")).to eq("")
      expect(html_to_markdown("<strong>   </strong>")).to eq("")
      expect(html_to_markdown("Some<strong> </strong>text")).to eq("Some text")
      expect(html_to_markdown("Some<strong>    </strong>text")).to eq("Some text")
    end

    it "handles <em>" do
      expect(html_to_markdown("<em></em>")).to eq("")
      expect(html_to_markdown("<em>   </em>")).to eq("")
      expect(html_to_markdown("Some<em> </em>text")).to eq("Some text")
      expect(html_to_markdown("Some<em>    </em>text")).to eq("Some text")
    end
  end

  context "with spaces around text" do
    it "handles <strong>" do
      expect(html_to_markdown("<strong> Bold</strong>")).to eq("**Bold**")
      expect(html_to_markdown("<strong>     Bold</strong>")).to eq("**Bold**")
      expect(html_to_markdown("<strong>Bold </strong>")).to eq("**Bold**")
      expect(html_to_markdown("<strong>Bold     </strong>")).to eq("**Bold**")
      expect(html_to_markdown("Some<strong> bold</strong> text")).to eq("Some **bold** text")
      expect(html_to_markdown("Some<strong>     bold</strong> text")).to eq("Some **bold** text")
      expect(html_to_markdown("Some <strong>bold </strong>text")).to eq("Some **bold** text")
      expect(html_to_markdown("Some <strong>bold     </strong>text")).to eq("Some **bold** text")
    end

    it "handles <em>" do
      expect(html_to_markdown("<em> Italic</em>")).to eq("*Italic*")
      expect(html_to_markdown("<em>     Italic</em>")).to eq("*Italic*")
      expect(html_to_markdown("<em>Italic </em>")).to eq("*Italic*")
      expect(html_to_markdown("<em>Italic     </em>")).to eq("*Italic*")
      expect(html_to_markdown("Some<em> italic</em> text")).to eq("Some *italic* text")
      expect(html_to_markdown("Some<em>     italic</em> text")).to eq("Some *italic* text")
      expect(html_to_markdown("Some <em>italic </em>text")).to eq("Some *italic* text")
      expect(html_to_markdown("Some <em>italic     </em>text")).to eq("Some *italic* text")
    end
  end

  it "supports <table>" do
    html = <<~HTML
      <table>
        <thead>
          <tr>
            <th>This</th>
            <th>is</th>
            <th>the</th>
            <th><i>headers</i></th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>I am</td>
            <td>the</td>
            <td><b>first</b></td>
            <td>row</td>
          </tr>
          <tr>
            <td>And this</td>
            <td>is the</td>
            <td>2<sup>nd</sup></td>
            <td>line</td>
          </tr>
        </tbody>
        <tfoot>
          <tr>
            <td>This</td>
            <td>is</td>
            <td>the</td>
            <td>footer</td>
          </tr>
        </tfoot>
      </table>
    HTML

    markdown = <<~MD
      | This | is | the | *headers* |
      | - | - | - | - |
      | I am | the | **first** | row |
      | And this | is the | 2<sup>nd</sup> | line |
      | This | is | the | footer |
    MD

    expect(html_to_markdown(html)).to eq(markdown.strip)

    expect(html_to_markdown("<table><tr><td>Hello</td><td>World</td></tr></table>")).to eq(
      "| Hello | World |\n| - | - |",
    )
  end

  it "keeps HTML for badly formatted <table>" do
    html = <<~HTML
      <table>
        <tr>
          <th>1</th>
          <th>2</th>
          <th>3</th>
          <th>4</th>
        </tr>
        <tr>
          <td>&lt;One&gt;</td>
          <td><strong>Two</strong></td>
          <td>Three<script>alert("foo")</script></td>
        </tr>
      </table>
    HTML

    markdown = <<~MD
      <table>
      <tr>
      <th>

      1

      </th>
      <th>

      2

      </th>
      <th>

      3

      </th>
      <th>

      4

      </th>
      </tr>
      <tr>
      <td>

      &lt;One&gt;

      </td>
      <td>

      **Two**

      </td>
      <td>

      Three

      </td>
      </tr>
      </table>
    MD

    expect(html_to_markdown(html)).to eq(markdown.strip)
  end

  it "keeps HTML for <table> with colspan" do
    html = <<~HTML
      <table>
        <tr>
          <th>1</th>
          <th>2</th>
        </tr>
        <tr>
          <td colspan="2">One / Two</td>
        </tr>
      </table>
    HTML

    markdown = <<~MD
      <table>
      <tr>
      <th>

      1

      </th>
      <th>

      2

      </th>
      </tr>
      <tr>
      <td colspan="2">

      One / Two

      </td>
      </tr>
      </table>
    MD

    expect(html_to_markdown(html)).to eq(markdown.strip)
  end

  it "keeps HTML for <table> with rowspan" do
    html = <<~HTML
      <table>
        <tr>
          <th>1</th>
          <th>2</th>
        </tr>
        <tr>
          <td>A</td>
          <td rowspan="2">B</td>
        </tr>
        <tr>
          <td>C</td>
        </tr>
      </table>
    HTML

    markdown = <<~MD
      <table>
      <tr>
      <th>

      1

      </th>
      <th>

      2

      </th>
      </tr>
      <tr>
      <td>

      A

      </td>
      <td rowspan="2">

      B

      </td>
      </tr>
      <tr>
      <td>

      C

      </td>
      </tr>
      </table>
    MD

    expect(html_to_markdown(html)).to eq(markdown.strip)
  end
end
