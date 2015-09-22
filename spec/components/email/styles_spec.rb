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

    # Pending due to email effort @coding-horror made in d2fb2bc4c
    skip "adds a max-width to images" do
      frag = basic_fragment("<img src='gigantic.jpg'>")
      expect(frag.at("img")["style"]).to match("max-width")
    end

    it "adds a width and height to images with an emoji path" do
      frag = basic_fragment("<img src='/images/emoji/fish.png' class='emoji'>")
      expect(frag.at("img")["width"]).to eq("20")
      expect(frag.at("img")["height"]).to eq("20")
    end

    it "converts relative paths to absolute paths" do
      frag = basic_fragment("<img src='/some-image.png'>")
      expect(frag.at("img")["src"]).to eq("#{Discourse.base_url}/some-image.png")
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
      frag = html_fragment("<a href>wat</a>")
      expect(frag.at('a')['style']).to be_present
    end

    it "attaches a style to a tags" do
      frag = html_fragment("<a href>wat</a>")
      expect(frag.at('a')['style']).to be_present
    end

    it "attaches a style to ul and li tags" do
      frag = html_fragment("<ul><li>hello</li></ul>")
      expect(frag.at('ul')['style']).to be_present
      expect(frag.at('li')['style']).to be_present
    end

    it "converts iframes to links" do
      iframe_url = "http://www.youtube.com/embed/7twifrxOTQY?feature=oembed&wmode=opaque"
      frag = html_fragment("<iframe src=\"#{iframe_url}\"></iframe>")
      expect(frag.at('iframe')).to be_blank
      expect(frag.at('a')).to be_present
      expect(frag.at('a')['href']).to eq(iframe_url)
    end

    it "won't allow non URLs in iframe src, strips them with no link" do
      iframe_url = "alert('xss hole')"
      frag = html_fragment("<iframe src=\"#{iframe_url}\"></iframe>")
      expect(frag.at('iframe')).to be_blank
      expect(frag.at('a')).to be_blank
    end
  end

  context "rewriting protocol relative URLs to the forum" do
    it "doesn't rewrite a url to another site" do
      frag = html_fragment('<a href="//youtube.com/discourse">hello</a>')
      expect(frag.at('a')['href']).to eq("//youtube.com/discourse")
    end

    context "without https" do
      before do
        SiteSetting.stubs(:use_https).returns(false)
      end

      it "rewrites the href to have http" do
        frag = html_fragment('<a href="//test.localhost/discourse">hello</a>')
        expect(frag.at('a')['href']).to eq("http://test.localhost/discourse")
      end

      it "rewrites the href for attachment files to have http" do
        frag = html_fragment('<a class="attachment" href="//try-discourse.global.ssl.fastly.net/uploads/default/368/40b610b0aa90cfcf.txt">attachment_file.txt</a>')
        expect(frag.at('a')['href']).to eq("http://try-discourse.global.ssl.fastly.net/uploads/default/368/40b610b0aa90cfcf.txt")
      end

      it "rewrites the src to have http" do
        frag = html_fragment('<img src="//test.localhost/blah.jpg">')
        expect(frag.at('img')['src']).to eq("http://test.localhost/blah.jpg")
      end
    end

    context "with https" do
      before do
        SiteSetting.stubs(:use_https).returns(true)
      end

      it "rewrites the forum URL to have https" do
        frag = html_fragment('<a href="//test.localhost/discourse">hello</a>')
        expect(frag.at('a')['href']).to eq("https://test.localhost/discourse")
      end

      it "rewrites the href for attachment files to have https" do
        frag = html_fragment('<a class="attachment" href="//try-discourse.global.ssl.fastly.net/uploads/default/368/40b610b0aa90cfcf.txt">attachment_file.txt</a>')
        expect(frag.at('a')['href']).to eq("https://try-discourse.global.ssl.fastly.net/uploads/default/368/40b610b0aa90cfcf.txt")
      end

      it "rewrites the src to have https" do
        frag = html_fragment('<img src="//test.localhost/blah.jpg">')
        expect(frag.at('img')['src']).to eq("https://test.localhost/blah.jpg")
      end
    end

  end

  context "strip_avatars_and_emojis" do
    it "works for lonesome emoji with no title" do
      emoji = "<img src='/images/emoji/emoji_one/crying_cat_face.png'>"
      style = Email::Styles.new(emoji)
      style.strip_avatars_and_emojis
      expect(style.to_html).to match_html(emoji)
    end

    it "works for lonesome emoji with title" do
      emoji = "<img title='cry_cry' src='/images/emoji/emoji_one/crying_cat_face.png'>"
      style = Email::Styles.new(emoji)
      style.strip_avatars_and_emojis
      expect(style.to_html).to match_html("cry_cry")
    end
  end


end
