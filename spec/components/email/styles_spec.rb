# frozen_string_literal: true

require 'rails_helper'
require 'email'

describe Email::Styles do
  let(:attachments) { {} }

  def basic_fragment(html)
    styler = Email::Styles.new(html)
    styler.format_basic
    Nokogiri::HTML5.fragment(styler.to_html)
  end

  def html_fragment(html)
    styler = Email::Styles.new(html)
    styler.format_basic
    styler.format_html
    Nokogiri::HTML5.fragment(styler.to_html)
  end

  context "basic formatter" do
    it "adds a max-width to large images" do
      frag = basic_fragment("<img height='auto' width='auto' src='gigantic.jpg'>")
      expect(frag.at("img")["style"]).to match("max-width")
    end

    it "adds a width and height to emojis" do
      frag = basic_fragment("<img src='/images/emoji/fish.png' class='emoji'>")
      expect(frag.at("img")["width"]).to eq("20")
      expect(frag.at("img")["height"]).to eq("20")
    end

    it "adds a width and height to custom emojis" do
      frag = basic_fragment("<img src='/uploads/default/_emoji/fish.png' class='emoji emoji-custom'>")
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

    it "won't allow empty iframe src, strips them with no link" do
      frag = html_fragment("<iframe src=''></iframe>")
      expect(frag.at('iframe')).to be_blank
      expect(frag.at('a')).to be_blank
    end

    it "prefers data-original-href attribute to get iframe link" do
      original_url = "https://vimeo.com/329875646/85f1546a42"
      iframe_url = "https://player.vimeo.com/video/329875646"
      frag = html_fragment("<iframe src=\"#{iframe_url}\" data-original-href=\"#{original_url}\"></iframe>")
      expect(frag.at('iframe')).to be_blank
      expect(frag.at('a')).to be_present
      expect(frag.at('a')['href']).to eq(original_url)
    end
  end

  context "rewriting protocol relative URLs to the forum" do
    it "doesn't rewrite a url to another site" do
      frag = html_fragment('<a href="//youtube.com/discourse">hello</a>')
      expect(frag.at('a')['href']).to eq("//youtube.com/discourse")
    end

    context "without https" do
      before do
        SiteSetting.force_https = false
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
        SiteSetting.force_https = true
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

    it "works if img tag has no attrs" do
      cooked = "Create a method for click on image and use ng-click in <img> in your slide box...it is simple"
      style = Email::Styles.new(cooked)
      style.strip_avatars_and_emojis
      expect(style.to_html).to include(cooked)
    end
  end

  context "onebox_styles" do
    it "renders quote as <blockquote>" do
      fragment = html_fragment('<aside class="quote"> <div class="title"> <div class="quote-controls"> <i class="fa fa-chevron-down" title="expand/collapse"></i><a href="/t/xyz/123" title="go to the quoted post" class="back"></a> </div> <img alt="" width="20" height="20" src="https://cdn-enterprise.discourse.org/boingboing/user_avatar/bbs.boingboing.net/techapj/40/54379_1.png" class="avatar">techAPJ: </div> <blockquote> <p>lorem ipsum</p> </blockquote> </aside>')
      expect(fragment.to_s.squish).to match(/^<blockquote.+<\/blockquote>$/)
    end
  end

  context "replace_secure_media_urls" do
    before do
      setup_s3
      SiteSetting.secure_media = true
    end

    let(:attachments) { { 'testimage.png' => stub(url: 'email/test.png') } }
    it "replaces secure media within a link with a placeholder" do
      frag = html_fragment("<a href=\"#{Discourse.base_url}\/secure-media-uploads/original/1X/testimage.png\"><img src=\"/secure-media-uploads/original/1X/testimage.png\"></a>")
      expect(frag.at('img')).not_to be_present
      expect(frag.to_s).to include("Redacted")
    end

    it "replaces secure images with a placeholder" do
      frag = html_fragment("<img src=\"/secure-media-uploads/original/1X/testimage.png\">")
      expect(frag.at('img')).not_to be_present
      expect(frag.to_s).to include("Redacted")
    end

    it "does not replace topic links with secure-media-uploads in the name" do
      frag = html_fragment("<a href=\"#{Discourse.base_url}\/t/secure-media-uploads/235723\">Visit Topic</a>")
      expect(frag.to_s).not_to include("Redacted")
    end
  end

  context "inline_secure_images" do
    before do
      setup_s3
      SiteSetting.secure_media = true
    end

    let(:attachments) { { 'testimage.png' => stub(url: 'cid:email/test.png') } }
    fab!(:upload) { Fabricate(:upload, original_filename: 'testimage.png', secure: true, sha1: '123456') }
    let(:html) { "<a href=\"#{Discourse.base_url}\/secure-media-uploads/original/1X/123456.png\"><img src=\"/secure-media-uploads/original/1X/123456.png\" width=\"20\" height=\"30\"></a>" }

    def strip_and_inline
      # strip out the secure media
      styler = Email::Styles.new(html)
      styler.format_basic
      styler.format_html
      html = styler.to_html

      # pass in the attachments to match uploads based on sha + original filename
      styler = Email::Styles.new(html)
      styler.inline_secure_images(attachments)
      @frag = Nokogiri::HTML5.fragment(styler.to_s)
    end

    it "inlines attachments where stripped-secure-media data attr is present" do
      strip_and_inline
      expect(@frag.to_s).to include("cid:email/test.png")
      expect(@frag.css('[data-stripped-secure-media]')).not_to be_present
      expect(@frag.children.attr('style').value).to eq("width: 20px; height: 30px;")
    end

    it "does not inline anything if the upload cannot be found" do
      upload.update(sha1: 'blah12')
      strip_and_inline

      expect(@frag.to_s).not_to include("cid:email/test.png")
      expect(@frag.css('[data-stripped-secure-media]')).to be_present
    end

    context "when an optimized image is used instead of the original" do
      let(:html) { "<a href=\"#{Discourse.base_url}\/secure-media-uploads/optimized/2X/1/123456_2_20x30.png\"><img src=\"/secure-media-uploads/optimized/2X/1/123456_2_20x30.png\" width=\"20\" height=\"30\"></a>" }

      it "inlines attachments where the stripped-secure-media data attr is present" do
        optimized = Fabricate(:optimized_image, upload: upload, width: 20, height: 30)
        strip_and_inline
        expect(@frag.to_s).to include("cid:email/test.png")
        expect(@frag.css('[data-stripped-secure-media]')).not_to be_present
        expect(@frag.children.attr('style').value).to eq("width: 20px; height: 30px;")
      end
    end

    context "when inlining an originally oneboxed image" do
      before do
        SiteSetting.authorized_extensions = "*"
      end

      let(:siteicon) { Fabricate(:upload, original_filename: "siteicon.ico") }
      let(:attachments) do
        {
          'testimage.png' => stub(url: 'cid:email/test.png'),
          'siteicon.ico' => stub(url: 'cid:email/test2.ico')
        }
      end
      let(:html) do
        <<~HTML
<aside class="onebox allowlistedgeneric">
  <header class="source">
      <img src="#{Discourse.base_url}/secure-media-uploads/original/1X/#{siteicon.sha1}.ico" class="site-icon" width="64" height="64">
      <a href="https://test.com/article" target="_blank" rel="noopener" title="02:33PM - 24 October 2020">Test</a>
  </header>
  <article class="onebox-body">
    <div class="aspect-image" style="--aspect-ratio:20/30;"><img src="#{Discourse.base_url}/secure-media-uploads/optimized/2X/1/123456_2_20x30.png" class="thumbnail d-lazyload" width="20" height="30" srcset="#{Discourse.base_url}/secure-media-uploads/optimized/2X/1/123456_2_20x30.png"></div>

<h3><a href="https://test.com/article" target="_blank" rel="noopener">Test</a></h3>

<p>This is a test onebox.</p>

  </article>
  <div class="onebox-metadata">
  </div>
  <div style="clear: both"></div>
</aside>
        HTML
      end

      it "keeps the special site icon width and height and onebox styles" do
        optimized = Fabricate(:optimized_image, upload: upload, width: 20, height: 30)
        strip_and_inline
        expect(@frag.to_s).to include("cid:email/test.png")
        expect(@frag.to_s).to include("cid:email/test2.ico")
        expect(@frag.css('[data-sripped-secure-media]')).not_to be_present
        expect(@frag.css('[data-embedded-secure-image]')[0].attr('style')).to eq('width: 16px; height: 16px;')
        expect(@frag.css('[data-embedded-secure-image]')[1].attr('style')).to eq('width: 60px; max-height: 80%; max-width: 20%; height: auto; float: left; margin-right: 10px;')
      end
    end
  end
end
