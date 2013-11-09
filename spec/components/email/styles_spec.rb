require 'spec_helper'
require 'email'

describe Email::Styles do

  def basic_fragment(html)
    styler = Email::Styles.new(html)
    styler.format_basic
    Nokogiri::HTML.fragment(styler.to_html)
  end

  def html_fragment(html)
    styler = Email::Styles.new(html)
    styler.format_basic
    styler.format_html
    Nokogiri::HTML.fragment(styler.to_html)
  end

  context "basic formatter" do

    it "works with an empty string" do
      style = Email::Styles.new("")
      style.format_basic
      expect(style.to_html).to be_blank
    end

    it "adds a max-width to images" do
      frag = basic_fragment("<img src='gigantic.jpg'>")
      expect(frag.at("img")["style"]).to match("max-width")
    end

    it "adds a width and height to images with an emoji path" do
      frag = basic_fragment("<img src='/assets/emoji/fish.png'>")
      expect(frag.at("img")["width"]).to eq("20")
      expect(frag.at("img")["height"]).to eq("20")
    end

    it "converts relative paths to absolute paths" do
      frag = basic_fragment("<img src='/some-image.png'>")
      expect(frag.at("img")["src"]).to eq("#{Discourse.base_url}/some-image.png")
    end

    it "prefixes schemaless image urls with http:" do
      frag = basic_fragment("<img src='//www.discourse.com/some-image.gif'>")
      expect(frag.at("img")["src"]).to eq("http://www.discourse.com/some-image.gif")
    end

    it "strips classes and ids" do
      frag = basic_fragment("<div class='foo' id='bar'><div class='foo' id='bar'></div></div>")
      expect(frag.to_html).to eq("<div><div></div></div>")
    end

  end

  context "html template formatter" do
    it "works with an empty string" do
      style = Email::Styles.new("")
      style.format_html
      expect(style.to_html).to be_blank
    end

    it "attaches a style to h3 tags" do
      frag = html_fragment("<h3>hello</h3>")
      expect(frag.at('h3')['style']).to be_present
    end

    it "attaches a style to hr tags" do
      frag = html_fragment("hello<hr>")
      expect(frag.at('hr')['style']).to be_present
    end

    it "attaches a style to a tags" do
      frag = html_fragment("<a href='#'>wat</a>")
      expect(frag.at('a')['style']).to be_present
    end

    it "attaches a style to a tags" do
      frag = html_fragment("<a href='#'>wat</a>")
      expect(frag.at('a')['style']).to be_present
    end

    it "attaches a style to ul and li tags" do
      frag = html_fragment("<ul><li>hello</li></ul>")
      expect(frag.at('ul')['style']).to be_present
      expect(frag.at('li')['style']).to be_present
    end

    it "removes pre tags but keeps their contents" do
      style = Email::Styles.new("<pre>hello</pre>")
      style.format_basic
      style.format_html
      expect(style.to_html).to eq("hello")
    end
  end


end
