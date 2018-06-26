require 'rails_helper'
require 'plain_text_to_markdown'

describe PlainTextToMarkdown do
  def to_markdown(text, opts = {})
    PlainTextToMarkdown.new(text, opts).to_markdown
  end

  let(:nbsp) { "&nbsp;" }

  context "quotes" do
    it "uses the correct quote level" do
      expect(to_markdown("> foo")).to eq("> foo")
      expect(to_markdown(">>> foo")).to eq(">>> foo")
      expect(to_markdown(">>>>>>> foo")).to eq(">>>>>>> foo")
    end

    it "ignores the first whitespace after the quote identifier" do
      expect(to_markdown(">foo")).to eq("> foo")
      expect(to_markdown("> foo")).to eq("> foo")
      expect(to_markdown(">\tfoo")).to eq("> foo")

      expect(to_markdown(">  foo")).to eq(">  foo")
      expect(to_markdown(">\t foo")).to eq(">  foo")
    end

    it "adds a blank line after a quote if it is followed by text" do
      expect(to_markdown("> foo\nbar")).to eq("> foo\n\nbar")
      expect(to_markdown(">> foo\nbar")).to eq(">> foo\n\nbar")
    end

    it "ignores multiple consecutive blank lines" do
      expect(to_markdown("> foo\n\nbar")).to eq("> foo\n\nbar")
      expect(to_markdown("> foo\n\n\nbar")).to eq("> foo\n\nbar")
      expect(to_markdown("> foo\n> \n>\n>\n> bar")).to eq("> foo\n>\n> bar")
    end

    it "adds an additional line with quote identifier if the quote level is decreasing" do
      expect(to_markdown(">> foo\n>bar")).to eq(">> foo\n>\n> bar")
      expect(to_markdown(">>>> foo\n>bar")).to eq(">>>> foo\n>\n> bar")
      expect(to_markdown(">> foo\nno quote\n>bar")).to eq(">> foo\n\nno quote\n> bar")
    end

    it "does not add an additional line with quote identifier if the quote level is decreasing and text is blank" do
      expect(to_markdown(">>> foo\n>>\n>> bar")).to eq(">>> foo\n>>\n>> bar")
    end
  end

  context "special characters" do
    it "escapes special Markdown characters" do
      expect(to_markdown('\ backslash')).to eq('\\\\ backslash')
      expect(to_markdown('` backtick')).to eq('\` backtick')
      expect(to_markdown('* asterisk')).to eq('\* asterisk')
      expect(to_markdown('_ underscore')).to eq('\_ underscore')
      expect(to_markdown('{} curly braces')).to eq('\{\} curly braces')
      expect(to_markdown('[] square brackets')).to eq('\[\] square brackets')
      expect(to_markdown('() parentheses')).to eq('\(\) parentheses')
      expect(to_markdown('# hash mark')).to eq('\# hash mark')
      expect(to_markdown('+ plus sign')).to eq('\+ plus sign')
      expect(to_markdown('- minus sign')).to eq('\- minus sign')
      expect(to_markdown('. dot')).to eq('\. dot')
      expect(to_markdown('! exclamation mark')).to eq('\! exclamation mark')
      expect(to_markdown('~ tilde')).to eq('\~ tilde')
    end

    it "escapes special HTML characters" do
      expect(to_markdown("' single quote")).to eq("&#39; single quote")
      expect(to_markdown("\" double quote")).to eq("&quot; double quote")
      expect(to_markdown("& ampersand")).to eq("&amp; ampersand")
      expect(to_markdown("<> less-than and greater-than sign")).to eq("&lt;&gt; less\\-than and greater\\-than sign")
    end

    it "escapes special characters but ignores links" do
      expect(to_markdown("*some text* https://www.example.com/foo.html?a=1&b=0 & <https://www.example.com/bar.html?a=1&b=0> *more text*"))
        .to eq("\\*some text\\* https://www.example.com/foo.html?a=1&b=0 &amp; &lt;https://www.example.com/bar.html?a=1&b=0&gt; \\*more text\\*")
    end
  end

  context "indentation" do
    it "does not replace one leading whitespace" do
      expect(to_markdown(" foo")).to eq(" foo")
    end

    it "replaces leading whitespaces with non-breaking spaces" do
      expect(to_markdown("  foo")).to eq("#{nbsp}#{nbsp}foo")
      expect(to_markdown("    foo")).to eq("#{nbsp}#{nbsp}#{nbsp}#{nbsp}foo")
    end

    it "replaces each leading tabs with two non-breaking spaces" do
      expect(to_markdown("\tfoo")).to eq("#{nbsp}#{nbsp}foo")
      expect(to_markdown(" \tfoo")).to eq("#{nbsp}#{nbsp}#{nbsp}foo")
      expect(to_markdown("\t foo")).to eq("#{nbsp}#{nbsp}#{nbsp}foo")
      expect(to_markdown(" \t foo")).to eq("#{nbsp}#{nbsp}#{nbsp}#{nbsp}foo")
      expect(to_markdown("\t\tfoo")).to eq("#{nbsp}#{nbsp}#{nbsp}#{nbsp}foo")
    end

    it "correctly replaces leading whitespaces within quotes" do
      expect(to_markdown(">  foo")).to eq(">  foo")
      expect(to_markdown(">   foo")).to eq("> #{nbsp}#{nbsp}foo")
    end

    it "does not replace whitespaces within text" do
      expect(to_markdown("foo    bar")).to eq("foo    bar")
      expect(to_markdown("foo\t\tbar")).to eq("foo\t\tbar")
    end
  end

  context "format=flowed" do
    it "concats lines ending with a space" do
      text = "Lorem ipsum dolor sit amet, consectetur \nadipiscing elit. Quasi vero, inquit, \nperpetua oratio rhetorum solum, non \netiam philosophorum sit."
      markdown = "Lorem ipsum dolor sit amet, consectetur adipiscing elit\\. Quasi vero, inquit, perpetua oratio rhetorum solum, non etiam philosophorum sit\\."

      expect(to_markdown(text, format_flowed: true)).to eq(markdown)
    end

    it "does not concat lines when there is an empty line between" do
      text = "Lorem ipsum dolor sit amet, consectetur \nadipiscing elit. \n\nQuasi vero, inquit, \nperpetua oratio rhetorum solum, non \netiam philosophorum sit."
      markdown = "Lorem ipsum dolor sit amet, consectetur adipiscing elit\\. \n\nQuasi vero, inquit, perpetua oratio rhetorum solum, non etiam philosophorum sit\\."

      expect(to_markdown(text, format_flowed: true)).to eq(markdown)
    end

    it "concats quoted lines ending with a space" do
      text = "> Lorem ipsum dolor sit amet, consectetur \n> adipiscing elit. Quasi vero, inquit, \n> perpetua oratio rhetorum solum, non \n> etiam philosophorum sit."
      markdown = "> Lorem ipsum dolor sit amet, consectetur adipiscing elit\\. Quasi vero, inquit, perpetua oratio rhetorum solum, non etiam philosophorum sit\\."

      expect(to_markdown(text, format_flowed: true)).to eq(markdown)
    end

    it "does not concat quoted lines ending with a space when the quote level differs" do
      text = "> Lorem ipsum dolor sit amet, consectetur \n> adipiscing elit. \n>> Quasi vero, inquit, \n>> perpetua oratio rhetorum solum, non \n> etiam philosophorum sit."
      markdown = "> Lorem ipsum dolor sit amet, consectetur adipiscing elit\\. \n>> Quasi vero, inquit, perpetua oratio rhetorum solum, non \n>\n> etiam philosophorum sit\\."

      expect(to_markdown(text, format_flowed: true)).to eq(markdown)
    end

    it "does not recognize a signature separator as start of flowed text" do
      text = "-- \nsignature line 1\nsignature line 2"
      markdown = "\\-\\- \nsignature line 1\nsignature line 2"

      expect(to_markdown(text, format_flowed: true)).to eq(markdown)
    end

    it "does not concat lines when there is a signature separator" do
      text = "Lorem ipsum \ndolor sit amet \n-- \nsignature line 1\nsignature line 2"
      markdown = "Lorem ipsum dolor sit amet \n\\-\\- \nsignature line 1\nsignature line 2"

      expect(to_markdown(text, format_flowed: true)).to eq(markdown)
    end

    it "removes the trailing space if DelSp is set to 'yes'" do
      text = "Lorem ipsum dolor sit amet, consectetur \nadipiscing elit. \nQuasi vero, inquit"
      markdown = "Lorem ipsum dolor sit amet, consecteturadipiscing elit\\.Quasi vero, inquit"

      expect(to_markdown(text, format_flowed: true, delete_flowed_space: true)).to eq(markdown)
    end
  end

  context "links" do
    it "removes duplicate links" do
      expect(to_markdown("foo https://www.example.com/foo.html <https://www.example.com/foo.html> bar"))
        .to eq("foo https://www.example.com/foo.html bar")

      expect(to_markdown("foo https://www.example.com/foo.html (https://www.example.com/foo.html) bar"))
        .to eq("foo https://www.example.com/foo.html bar")

      expect(to_markdown("foo https://www.example.com/foo.html https://www.example.com/foo.html bar"))
        .to eq("foo https://www.example.com/foo.html bar")
    end

    it "does not removes duplicate links when there is text between the links" do
      expect(to_markdown("foo https://www.example.com/foo.html bar https://www.example.com/foo.html baz"))
        .to eq("foo https://www.example.com/foo.html bar https://www.example.com/foo.html baz")
    end
  end

  context "code" do
    it "detects matching Markdown code block within backticks" do
      expect(to_markdown("foo\n```\n<this is code>\n```")).to eq("foo\n```\n<this is code>\n```")
    end

    it "does not detect Markdown code block when backticks are not on new line" do
      expect(to_markdown("foo\n```\n<this is code> ```")).to eq("foo\n\\`\\`\\`\n&lt;this is code&gt; \\`\\`\\`")
    end

    it "does not detect Markdown code block when backticks are indented by more than 3 whitespaces" do
      expect(to_markdown("foo\n ```\n<this is code>\n  ```")).to include("<this is code>")
      expect(to_markdown("foo\n   ```\n<this is code>\n ```")).to include("<this is code>")

      expect(to_markdown("foo\n    ```\n<this is code>\n```")).to include("&lt;this is code&gt;")
      expect(to_markdown("foo\n```\n<this is code>\n    ```")).to include("&lt;this is code&gt;")

      expect(to_markdown("foo\n       ```\n<this is code>\n```")).to include("&lt;this is code&gt;")
      expect(to_markdown("foo\n```\n<this is code>\n        ```")).to include("&lt;this is code&gt;")
    end
  end
end
