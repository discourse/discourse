require 'rails_helper'
require 'email'

describe Email::Styles do

  def basic_doc(html)
    styler = Email::Styles.new(html)
    styler.format_basic
    Nokogiri::HTML(styler.to_html)
  end

  def html_doc(html)
    styler = Email::Styles.new(html)
    styler.format_basic
    styler.format_html
    Nokogiri::HTML(styler.to_html)
  end

  context "basic formatter" do

    it "works with an empty string" do
      style = Email::Styles.new("")
      style.format_basic
      expect(style.to_html).to be_blank
    end

    # Pending due to email effort @coding-horror made in d2fb2bc4c
    skip "adds a max-width to images" do
      doc = basic_doc("<img src='gigantic.jpg'>")
      expect(doc.at("img")["style"]).to match("max-width")
    end

    it "adds a width and height to images with an emoji path" do
      doc = basic_doc("<img src='/images/emoji/fish.png' class='emoji'>")
      expect(doc.at("img")["width"]).to eq("20")
      expect(doc.at("img")["height"]).to eq("20")
    end

    it "converts relative paths to absolute paths" do
      doc = basic_doc("<img src='/some-image.png'>")
      expect(doc.at("img")["src"]).to eq("#{Discourse.base_url}/some-image.png")
    end

    it "strips classes and ids" do
      doc = basic_doc("<div class='foo' id='bar'><div class='foo' id='bar'></div></div>")
      expect(doc.to_html).to match(/<div><div><\/div><\/div>/)
    end

  end

  context "html template formatter" do
    it "works with an empty string" do
      style = Email::Styles.new("")
      style.format_html
      expect(style.to_html).to be_blank
    end

    it "attaches a style to h3 tags" do
      doc = html_doc("<h3>hello</h3>")
      expect(doc.at('h3')['style']).to be_present
    end

    it "attaches a style to hr tags" do
      doc = html_doc("hello<hr>")
      expect(doc.at('hr')['style']).to be_present
    end

    it "attaches a style to a tags" do
      doc = html_doc("<a href>wat</a>")
      expect(doc.at('a')['style']).to be_present
    end

    it "attaches a style to a tags" do
      doc = html_doc("<a href>wat</a>")
      expect(doc.at('a')['style']).to be_present
    end

    it "attaches a style to ul and li tags" do
      doc = html_doc("<ul><li>hello</li></ul>")
      expect(doc.at('ul')['style']).to be_present
      expect(doc.at('li')['style']).to be_present
    end

    it "converts iframes to links" do
      iframe_url = "http://www.youtube.com/embed/7twifrxOTQY?feature=oembed&wmode=opaque"
      doc = html_doc("<iframe src=\"#{iframe_url}\"></iframe>")
      expect(doc.at('iframe')).to be_blank
      expect(doc.at('a')).to be_present
      expect(doc.at('a')['href']).to eq(iframe_url)
    end

    it "won't allow non URLs in iframe src, strips them with no link" do
      iframe_url = "alert('xss hole')"
      doc = html_doc("<iframe src=\"#{iframe_url}\"></iframe>")
      expect(doc.at('iframe')).to be_blank
      expect(doc.at('a')).to be_blank
    end
  end

  context "rewriting protocol relative URLs to the forum" do
    it "doesn't rewrite a url to another site" do
      doc = html_doc('<a href="//youtube.com/discourse">hello</a>')
      expect(doc.at('a')['href']).to eq("//youtube.com/discourse")
    end

    context "without https" do
      before do
        SiteSetting.stubs(:use_https).returns(false)
      end

      it "rewrites the href to have http" do
        doc = html_doc('<a href="//test.localhost/discourse">hello</a>')
        expect(doc.at('a')['href']).to eq("http://test.localhost/discourse")
      end

      it "rewrites the href for attachment files to have http" do
        doc = html_doc('<a class="attachment" href="//try-discourse.global.ssl.fastly.net/uploads/default/368/40b610b0aa90cfcf.txt">attachment_file.txt</a>')
        expect(doc.at('a')['href']).to eq("http://try-discourse.global.ssl.fastly.net/uploads/default/368/40b610b0aa90cfcf.txt")
      end

      it "rewrites the src to have http" do
        doc = html_doc('<img src="//test.localhost/blah.jpg">')
        expect(doc.at('img')['src']).to eq("http://test.localhost/blah.jpg")
      end
    end

    context "with https" do
      before do
        SiteSetting.stubs(:use_https).returns(true)
      end

      it "rewrites the forum URL to have https" do
        doc = html_doc('<a href="//test.localhost/discourse">hello</a>')
        expect(doc.at('a')['href']).to eq("https://test.localhost/discourse")
      end

      it "rewrites the href for attachment files to have https" do
        doc = html_doc('<a class="attachment" href="//try-discourse.global.ssl.fastly.net/uploads/default/368/40b610b0aa90cfcf.txt">attachment_file.txt</a>')
        expect(doc.at('a')['href']).to eq("https://try-discourse.global.ssl.fastly.net/uploads/default/368/40b610b0aa90cfcf.txt")
      end

      it "rewrites the src to have https" do
        doc = html_doc('<img src="//test.localhost/blah.jpg">')
        expect(doc.at('img')['src']).to eq("https://test.localhost/blah.jpg")
      end
    end

  end

  context "strip_avatars_and_emojis" do
    it "works for lonesome emoji with no title" do
      emoji = "<img src='/images/emoji/emoji_one/crying_cat_face.png'>"
      style = Email::Styles.new(emoji)
      style.strip_avatars_and_emojis
      expect(style.to_html).to match_html("<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\" \"http://www.w3.org/TR/REC-html40/loose.dtd\"><html><body>#{emoji}</body></html>")
    end

    it "works for lonesome emoji with title" do
      emoji = "<img title='cry_cry' src='/images/emoji/emoji_one/crying_cat_face.png'>"
      style = Email::Styles.new(emoji)
      style.strip_avatars_and_emojis
      expect(style.to_html).to match_html("<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.0 Transitional//EN\" \"http://www.w3.org/TR/REC-html40/loose.dtd\"><html><body>cry_cry</body></html>")
    end
  end


end
