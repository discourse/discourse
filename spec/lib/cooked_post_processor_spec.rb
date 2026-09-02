# frozen_string_literal: true

require "cooked_post_processor"
require "file_store/s3_store"

RSpec.describe CookedPostProcessor do
  fab!(:upload)
  fab!(:large_image_upload)
  fab!(:user_with_auto_groups) { Fabricate(:user, refresh_auto_groups: true) }
  let(:upload_path) { Discourse.store.upload_path }

  describe "#extract_images" do
    let(:post) { build(:post_with_plenty_of_images) }
    let(:cpp) { CookedPostProcessor.new(post) }

    it "does not extract emojis or images inside oneboxes or quotes" do
      expect(cpp.extract_images.length).to eq(0)
    end
  end

  describe "#get_size_from_attributes" do
    let(:post) { build(:post) }
    let(:cpp) { CookedPostProcessor.new(post) }

    it "returns the size when width and height are specified" do
      img = { "src" => "http://foo.bar/image3.png", "width" => 50, "height" => 70 }
      expect(cpp.get_size_from_attributes(img)).to eq([50, 70])
    end

    it "returns the size when width and height are floats" do
      img = { "src" => "http://foo.bar/image3.png", "width" => 50.2, "height" => 70.1 }
      expect(cpp.get_size_from_attributes(img)).to eq([50, 70])
    end

    it "resizes when only width is specified" do
      img = { "src" => "http://foo.bar/image3.png", "width" => 100 }
      FastImage.expects(:size).returns([200, 400])
      expect(cpp.get_size_from_attributes(img)).to eq([100, 200])
    end

    it "resizes when only height is specified" do
      img = { "src" => "http://foo.bar/image3.png", "height" => 100 }
      FastImage.expects(:size).returns([100, 300])
      expect(cpp.get_size_from_attributes(img)).to eq([33, 100])
    end

    it "doesn't raise an error with a weird url" do
      img = { "src" => nil, "height" => 100 }
      expect(cpp.get_size_from_attributes(img)).to be_nil
    end
  end

  describe "#get_size_from_image_sizes" do
    let(:post) { build(:post) }
    let(:cpp) { CookedPostProcessor.new(post) }

    let(:image_sizes) do
      { "http://my.discourse.org/image.png" => { "width" => 111, "height" => 222 } }
    end

    it "returns the size" do
      expect(cpp.get_size_from_image_sizes("/image.png", image_sizes)).to eq([111, 222])
    end

    it "returns nil whe img node has no src" do
      expect(cpp.get_size_from_image_sizes(nil, image_sizes)).to eq(nil)
    end
  end

  describe "#get_size" do
    let(:post) { build(:post) }
    let(:cpp) { CookedPostProcessor.new(post) }

    it "ensures urls are absolute" do
      cpp.expects(:is_valid_image_url?).with("http://test.localhost/relative/url/image.png")
      cpp.get_size("/relative/url/image.png")
    end

    it "ensures urls have a default scheme" do
      cpp.expects(:is_valid_image_url?).with("http://schemaless.url/image.jpg")
      cpp.get_size("//schemaless.url/image.jpg")
    end

    it "caches the results" do
      FastImage.expects(:size).returns([200, 400])
      cpp.get_size("http://foo.bar/image3.png")
      expect(cpp.get_size("http://foo.bar/image3.png")).to eq([200, 400])
    end
  end

  describe "#is_valid_image_url?" do
    let(:post) { build(:post) }
    let(:cpp) { CookedPostProcessor.new(post) }

    it "validates HTTP(s) urls" do
      expect(cpp.is_valid_image_url?("http://domain.com")).to eq(true)
      expect(cpp.is_valid_image_url?("https://domain.com")).to eq(true)
    end

    it "doesn't validate other urls" do
      expect(cpp.is_valid_image_url?("ftp://domain.com")).to eq(false)
      expect(cpp.is_valid_image_url?("ftps://domain.com")).to eq(false)
      expect(cpp.is_valid_image_url?("/tmp/image.png")).to eq(false)
      expect(cpp.is_valid_image_url?("//domain.com")).to eq(false)
    end

    it "doesn't throw an exception with a bad URI" do
      expect(cpp.is_valid_image_url?("http://do<main.com")).to eq(nil)
    end
  end

  describe "#get_filename" do
    let(:post) { build(:post) }
    let(:cpp) { CookedPostProcessor.new(post) }

    it "returns the filename of the src when there is no upload" do
      expect(cpp.get_filename(nil, "http://domain.com/image.png")).to eq("image.png")
    end

    it "returns the original filename of the upload when there is an upload" do
      upload = build(:upload, original_filename: "upload.jpg")
      expect(cpp.get_filename(upload, "http://domain.com/image.png")).to eq("upload.jpg")
    end

    it "returns a generic name for pasted images" do
      upload = build(:upload, original_filename: "blob.png")
      expect(cpp.get_filename(upload, "http://domain.com/image.png")).to eq(
        I18n.t("upload.pasted_image_filename"),
      )
    end
  end

  describe "#convert_to_link" do
    fab!(:thumbnail) { Fabricate(:optimized_image, upload: upload, width: 512, height: 384) }

    it "adds lightbox and optimizes images" do
      post =
        Fabricate(
          :post,
          user: user_with_auto_groups,
          raw: "![image|1024x768, 50%](#{large_image_upload.short_url})",
        )
      cpp = CookedPostProcessor.new(post, disable_dominant_color: true)
      cpp.post_process

      doc = Nokogiri::HTML5.fragment(cpp.html)

      expect(doc.css(".lightbox-wrapper").size).to eq(1)
      expect(doc.css("img").first["srcset"]).to_not eq(nil)
    end

    it "processes animated images correctly" do
      # skips optimization
      # skips lightboxing
      # adds "animated" class to element
      upload.update!(animated: true)
      post =
        Fabricate(
          :post,
          user: user_with_auto_groups,
          raw: "![image|1024x768, 50%](#{upload.short_url})",
        )

      cpp = CookedPostProcessor.new(post, disable_dominant_color: true)
      cpp.post_process

      doc = Nokogiri::HTML5.fragment(cpp.html)
      expect(doc.css(".lightbox-wrapper").size).to eq(0)
      expect(doc.css("img").first["src"]).to include(upload.url)
      expect(doc.css("img").first["srcset"]).to eq(nil)
      expect(doc.css("img.animated").size).to eq(1)
    end

    context "with giphy/tenor images" do
      before do
        CookedPostProcessor
          .any_instance
          .stubs(:get_size)
          .with("https://media2.giphy.com/media/7Oifk90VrCdNe/giphy.webp")
          .returns([311, 280])
        CookedPostProcessor
          .any_instance
          .stubs(:get_size)
          .with("https://media1.tenor.com/images/20c7ddd5e84c7427954f430439c5209d/tenor.gif")
          .returns([833, 104])
      end

      it "marks Giphy images as animated" do
        post =
          Fabricate(
            :post,
            user: user_with_auto_groups,
            raw: "![tennis-gif|311x280](https://media2.giphy.com/media/7Oifk90VrCdNe/giphy.webp)",
          )
        cpp = CookedPostProcessor.new(post, disable_dominant_color: true)
        cpp.post_process

        doc = Nokogiri::HTML5.fragment(cpp.html)
        expect(doc.css("img.animated").size).to eq(1)
      end

      it "marks Tenor images as animated" do
        post =
          Fabricate(
            :post,
            user: user_with_auto_groups,
            raw:
              "![cat](https://media1.tenor.com/images/20c7ddd5e84c7427954f430439c5209d/tenor.gif)",
          )
        cpp = CookedPostProcessor.new(post, disable_dominant_color: true)
        cpp.post_process

        doc = Nokogiri::HTML5.fragment(cpp.html)
        expect(doc.css("img.animated").size).to eq(1)
      end
    end

    it "optimizes and wraps images in quotes with lightbox wrapper" do
      post = Fabricate(:post, user: user_with_auto_groups, raw: <<~MD)
        [quote]
        ![image|1024x768, 50%](#{large_image_upload.short_url})
        [/quote]
      MD

      cpp = CookedPostProcessor.new(post, disable_dominant_color: true)
      cpp.post_process

      doc = Nokogiri::HTML5.fragment(cpp.html)
      expect(doc.css(".lightbox-wrapper").size).to eq(1)
      expect(doc.css("img").first["srcset"]).to_not eq(nil)
    end

    it "optimizes images in Onebox" do
      Oneboxer
        .expects(:onebox)
        .with("https://discourse.org", anything)
        .returns(
          "<aside class='onebox'><img src='#{large_image_upload.url}' width='512' height='384'></aside>",
        )

      post = Fabricate(:post, user: user_with_auto_groups, raw: "https://discourse.org")

      cpp = CookedPostProcessor.new(post, disable_dominant_color: true)
      cpp.post_process

      doc = Nokogiri::HTML5.fragment(cpp.html)
      expect(doc.css(".lightbox-wrapper").size).to eq(0)
      expect(doc.css("img").first["srcset"]).to eq(nil)
      expect(doc.css("img").first["src"]).to include("optimized")
      expect(doc.css("img").first["src"]).to include("512x384")
    end
  end

  describe "#post_process_oneboxes" do
    let(:post) { build(:post_with_youtube, id: 123) }
    let(:cpp) { CookedPostProcessor.new(post, invalidate_oneboxes: true) }

    before do
      Oneboxer
        .expects(:onebox)
        .with(
          "http://www.youtube.com/watch?v=9bZkp7q19f0",
          invalidate_oneboxes: true,
          user_id: nil,
          category_id: post.topic.category_id,
          locale: nil,
        )
        .returns("<div>GANGNAM STYLE</div>")

      cpp.post_process_oneboxes
    end

    it "inserts the onebox without wrapping p" do
      expect(cpp).to be_dirty
      expect(cpp.html).to match_html "<div>GANGNAM STYLE</div>"
    end

    describe "replacing downloaded onebox image" do
      let(:url) { "https://image.com/my-avatar" }
      let(:image_url) { "https://image.com/avatar.png" }

      it "successfully replaces the image" do
        Oneboxer
          .stubs(:onebox)
          .with(url, anything)
          .returns("<img class='onebox' src='#{image_url}' />")

        post = Fabricate(:post, user: user_with_auto_groups, raw: url)
        upload.update!(url: "https://test.s3.amazonaws.com/something.png", dominant_color: "00ffff")

        PostHotlinkedMedia.create!(
          url: "//image.com/avatar.png",
          post: post,
          status: "downloaded",
          upload: upload,
        )

        cpp = CookedPostProcessor.new(post, invalidate_oneboxes: true)
        stub_image_size(width: 100, height: 200)
        cpp.post_process_oneboxes

        expect(cpp.doc.to_s).to eq(
          "<p><img class=\"onebox\" src=\"#{upload.url}\" data-dominant-color=\"00ffff\" width=\"100\" height=\"200\"></p>",
        )

        upload.destroy!
        cpp = CookedPostProcessor.new(post, invalidate_oneboxes: true)
        stub_image_size(width: 100, height: 200)
        cpp.post_process_oneboxes

        expect(cpp.doc.to_s).to eq(
          "<p><img class=\"onebox\" src=\"#{image_url}\" width=\"100\" height=\"200\"></p>",
        )
        Oneboxer.unstub(:onebox)
      end

      context "when the post is should_secure_uploads and the upload is secure and secure uploads is enabled" do
        before do
          setup_s3
          upload.update(secure: true)

          SiteSetting.login_required = true
          SiteSetting.secure_uploads = true
        end

        it "does not use the direct URL, uses the cooked URL instead (because of the private ACL preventing w/h fetch)" do
          Oneboxer
            .stubs(:onebox)
            .with(url, anything)
            .returns("<img class='onebox' src='#{image_url}' />")

          post = Fabricate(:post, user: user_with_auto_groups, raw: url)
          upload.update!(
            url: "https://test.s3.amazonaws.com/something.png",
            dominant_color: "00ffff",
          )

          PostHotlinkedMedia.create!(
            url: "//image.com/avatar.png",
            post: post,
            status: "downloaded",
            upload: upload,
          )

          cooked_url = "https://localhost/secure-uploads/test.png"
          UrlHelper.expects(:cook_url).with(upload.url, secure: true).returns(cooked_url)

          cpp = CookedPostProcessor.new(post, invalidate_oneboxes: true)
          stub_image_size(width: 100, height: 200)
          cpp.post_process_oneboxes

          expect(cpp.doc.to_s).to eq(
            "<p><img class=\"onebox\" src=\"#{cooked_url}\" data-dominant-color=\"00ffff\" width=\"100\" height=\"200\"></p>",
          )
        end
      end
    end

    it "replaces large image placeholder" do
      SiteSetting.max_image_size_kb = 4096
      url = "https://image.com/avatar.png"

      Oneboxer.stubs(:onebox).with(url, anything).returns <<~HTML
          <a href="#{url}" target="_blank" rel="noopener" class="onebox">
            <img class='onebox' src='#{url}' />
          </a>
        HTML

      post = Fabricate(:post, user: user_with_auto_groups, raw: url)

      PostHotlinkedMedia.create!(url: "//image.com/avatar.png", post: post, status: "too_large")

      cpp = CookedPostProcessor.new(post, invalidate_oneboxes: true)
      cpp.post_process

      expect(cpp.doc.to_s).to match(/<div class="large-image-placeholder">/)
      expect(cpp.doc.to_s).to include(
        I18n.t("upload.placeholders.too_large_humanized", max_size: "4 MB"),
      )
    end

    it "removes large images from onebox" do
      url = "https://example.com/article"

      Oneboxer.stubs(:onebox).with(url, anything).returns <<~HTML
        <aside class="onebox allowlistedgeneric" data-onebox-src="https://example.com/article">
          <header class="source">
            <img src="https://example.com/favicon.ico" class="site-icon">
            <a href="https://example.com/article" target="_blank" rel="nofollow ugc noopener">Example Site</a>
          </header>
          <article class="onebox-body">
            <img src="https://example.com/article.jpeg" class="thumbnail">
            <h3><a href="https://example.com/article" target="_blank" rel="nofollow ugc noopener">Lorem Ispum</a></h3>
            <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer tellus neque, malesuada ac neque ac, tempus tincidunt lectus.</p>
          </article>
        </aside>
      HTML

      post = Fabricate(:post, user: user_with_auto_groups, raw: url)

      PostHotlinkedMedia.create!(url: "//example.com/favicon.ico", post: post, status: "too_large")
      PostHotlinkedMedia.create!(url: "//example.com/article.jpeg", post: post, status: "too_large")

      cpp = CookedPostProcessor.new(post, invalidate_oneboxes: true)
      cpp.post_process

      expect(cpp.doc).to match_html <<~HTML
        <aside class="onebox allowlistedgeneric" data-onebox-src="https://example.com/article">
          <header class="source">
            <a href="https://example.com/article" target="_blank" rel="noopener nofollow ugc">Example Site</a>
          </header>
          <article class="onebox-body">
            <h3><a href="https://example.com/article" target="_blank" rel="noopener nofollow ugc">Lorem Ispum</a></h3>
            <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer tellus neque, malesuada ac neque ac, tempus tincidunt lectus.</p>
          </article>
        </aside>
      HTML
    end

    it "replaces broken image placeholder" do
      url = "https://image.com/my-avatar"
      image_url = "https://image.com/avatar.png"

      Oneboxer
        .stubs(:onebox)
        .with(url, anything)
        .returns("<img class='onebox' src='#{image_url}' />")

      post = Fabricate(:post, user: user_with_auto_groups, raw: url)

      PostHotlinkedMedia.create!(
        url: "//image.com/avatar.png",
        post: post,
        status: "download_failed",
      )

      cpp = CookedPostProcessor.new(post, invalidate_oneboxes: true)
      cpp.post_process

      expect(cpp.doc.to_s).to have_tag("span.broken-image")
      expect(cpp.doc.to_s).to include(I18n.t("post.image_placeholder.broken"))
    end

    it "removes broken images from onebox" do
      url = "https://example.com/article"

      Oneboxer.stubs(:onebox).with(url, anything).returns <<~HTML
        <aside class="onebox allowlistedgeneric" data-onebox-src="https://example.com/article">
          <header class="source">
            <img src="https://example.com/favicon.ico" class="site-icon">
            <a href="https://example.com/article" target="_blank" rel="nofollow ugc noopener">Example Site</a>
          </header>
          <article class="onebox-body">
            <img src="https://example.com/article.jpeg" class="thumbnail">
            <h3><a href="https://example.com/article" target="_blank" rel="nofollow ugc noopener">Lorem Ispum</a></h3>
            <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer tellus neque, malesuada ac neque ac, tempus tincidunt lectus.</p>
          </article>
        </aside>
      HTML

      post = Fabricate(:post, user: user_with_auto_groups, raw: url)

      PostHotlinkedMedia.create!(
        url: "//example.com/favicon.ico",
        post: post,
        status: "download_failed",
      )
      PostHotlinkedMedia.create!(
        url: "//example.com/article.jpeg",
        post: post,
        status: "download_failed",
      )

      cpp = CookedPostProcessor.new(post, invalidate_oneboxes: true)
      cpp.post_process

      expect(cpp.doc).to match_html <<~HTML
        <aside class="onebox allowlistedgeneric" data-onebox-src="https://example.com/article">
          <header class="source">
            <a href="https://example.com/article" target="_blank" rel="noopener nofollow ugc">Example Site</a>
          </header>
          <article class="onebox-body">
            <h3><a href="https://example.com/article" target="_blank" rel="noopener nofollow ugc">Lorem Ispum</a></h3>
            <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Integer tellus neque, malesuada ac neque ac, tempus tincidunt lectus.</p>
          </article>
        </aside>
      HTML
    end
  end

  describe "#post_process_oneboxes removes nofollow if add_rel_nofollow_to_user_content is disabled" do
    let(:post) { build(:post_with_youtube, id: 123) }
    let(:cpp) { CookedPostProcessor.new(post, invalidate_oneboxes: true) }

    before do
      SiteSetting.add_rel_nofollow_to_user_content = false
      Oneboxer
        .expects(:onebox)
        .with(
          "http://www.youtube.com/watch?v=9bZkp7q19f0",
          invalidate_oneboxes: true,
          user_id: nil,
          category_id: post.topic.category_id,
          locale: nil,
        )
        .returns(
          '<aside class="onebox"><a href="https://www.youtube.com/watch?v=9bZkp7q19f0" rel="noopener nofollow ugc">GANGNAM STYLE</a></aside>',
        )
      cpp.post_process_oneboxes
    end

    it "removes nofollow noopener from links" do
      expect(cpp).to be_dirty
      expect(
        cpp.html,
      ).to match_html '<aside class="onebox"><a href="https://www.youtube.com/watch?v=9bZkp7q19f0" rel="noopener">GANGNAM STYLE</a></aside>'
    end
  end

  describe "#post_process_oneboxes removes nofollow if user is tl3" do
    let(:post) { build(:post_with_youtube, id: 123) }
    let(:cpp) { CookedPostProcessor.new(post, invalidate_oneboxes: true) }

    before do
      post.user.trust_level = TrustLevel[3]
      post.user.save!
      SiteSetting.add_rel_nofollow_to_user_content = true
      SiteSetting.tl3_links_no_follow = false
      Oneboxer
        .expects(:onebox)
        .with(
          "http://www.youtube.com/watch?v=9bZkp7q19f0",
          invalidate_oneboxes: true,
          user_id: nil,
          category_id: post.topic.category_id,
          locale: nil,
        )
        .returns(
          '<aside class="onebox"><a href="https://www.youtube.com/watch?v=9bZkp7q19f0" rel="noopener nofollow ugc">GANGNAM STYLE</a></aside>',
        )
      cpp.post_process_oneboxes
    end

    it "removes nofollow ugc from links" do
      expect(cpp).to be_dirty
      expect(
        cpp.html,
      ).to match_html '<aside class="onebox"><a href="https://www.youtube.com/watch?v=9bZkp7q19f0" rel="noopener">GANGNAM STYLE</a></aside>'
    end
  end

  describe "#post_process_oneboxes with oneboxed image" do
    let(:post) { build(:post_with_youtube, id: 123) }
    let(:cpp) { CookedPostProcessor.new(post, invalidate_oneboxes: true) }

    it "applies aspect ratio to container" do
      Oneboxer
        .expects(:onebox)
        .with(
          "http://www.youtube.com/watch?v=9bZkp7q19f0",
          invalidate_oneboxes: true,
          user_id: nil,
          category_id: post.topic.category_id,
          locale: nil,
        )
        .returns(
          "<aside class='onebox'><div class='scale-images'><img src='/img.jpg' width='400' height='500'/></div></div>",
        )

      cpp.post_process_oneboxes

      expect(cpp.html).to match_html(
        '<aside class="onebox"><div class="aspect-image-full-size" style="--aspect-ratio:400/500;"><img src="/img.jpg"></div></aside>',
      )
    end

    it "applies aspect ratio when wrapped in link" do
      Oneboxer
        .expects(:onebox)
        .with(
          "http://www.youtube.com/watch?v=9bZkp7q19f0",
          invalidate_oneboxes: true,
          user_id: nil,
          category_id: post.topic.category_id,
          locale: nil,
        )
        .returns(
          "<aside class='onebox'><div class='scale-images'><a href='https://example.com'><img src='/img.jpg' width='400' height='500'/></a></div></div>",
        )

      cpp.post_process_oneboxes

      expect(cpp.html).to match_html(
        '<aside class="onebox"><div class="aspect-image-full-size" style="--aspect-ratio:400/500;"><a href="https://example.com"><img src="/img.jpg"></a></div></aside>',
      )
    end
  end

  describe "#post_process_oneboxes with square image" do
    fab!(:post) { Fabricate(:post, raw: "https://square-image.com/onebox") }

    it "generates a onebox-avatar class" do
      body = <<~HTML
      <html>
      <head>
      <meta property='og:title' content="Page awesome">
      <meta property='og:image' content="https://image.com/avatar.png">
      <meta property='og:description' content="Page awesome desc">
      </head>
      </html>
      HTML

      stub_request(:head, post.raw)
      stub_request(:get, post.raw).to_return(body: body)

      # not an ideal stub but shipping the whole image to fast image can add
      # a lot of cost to this test
      stub_image_size(width: 200, height: 200)

      cpp = CookedPostProcessor.new(post, invalidate_oneboxes: true)
      cpp.post_process_oneboxes

      expect(cpp.doc.to_s).not_to include("aspect-image")
      expect(cpp.doc.to_s).to include("onebox-avatar")
    end
  end

  describe "#remove_user_ids" do
    let(:topic) { Fabricate(:topic) }

    let(:post) { Fabricate(:post, user: user_with_auto_groups, raw: <<~RAW) }
        link to a topic: #{topic.url}?u=foo

        a tricky link to a topic: #{topic.url}?bob=bob;u=sam&jane=jane

        link to an external topic: https://google.com/?u=bar

        a malformed url: https://www.example.com/#123#4
      RAW

    let(:cpp) { CookedPostProcessor.new(post, disable_dominant_color: true) }

    it "does remove user ids" do
      cpp.remove_user_ids

      expect(cpp.html).to have_tag("a", with: { href: topic.url })
      expect(cpp.html).to have_tag("a", with: { href: "#{topic.url}?bob=bob&jane=jane" })
      expect(cpp.html).to have_tag("a", with: { href: "https://google.com/?u=bar" })
      expect(cpp.html).to have_tag("a", with: { href: "https://www.example.com/#123#4" })
    end

    it "preserves encoded characters in the remaining query params" do
      post = Fabricate(:post, user: user_with_auto_groups, raw: "link: #{topic.url}?ref=a%26b&u=99")
      cpp = CookedPostProcessor.new(post, disable_dominant_color: true)

      cpp.remove_user_ids

      expect(cpp.html).to have_tag("a", with: { href: "#{topic.url}?ref=a%26b" })
    end
  end

  describe "#is_a_hyperlink?" do
    let(:post) { build(:post) }
    let(:cpp) { CookedPostProcessor.new(post) }
    let(:doc) do
      Nokogiri::HTML5.fragment(
        '<body><div><a><img id="linked_image"></a><p><img id="standard_image"></p></div></body>',
      )
    end

    it "is true when the image is inside a link" do
      img = doc.css("img#linked_image").first
      expect(cpp.is_a_hyperlink?(img)).to eq(true)
    end

    it "is false when the image is not inside a link" do
      img = doc.css("img#standard_image").first
      expect(cpp.is_a_hyperlink?(img)).to eq(false)
    end
  end

  describe "grant badges" do
    let(:cpp) { CookedPostProcessor.new(post) }

    context "with emoji inside a quote" do
      let(:post) do
        Fabricate(
          :post,
          user: user_with_auto_groups,
          raw: "time to eat some sweet \n[quote]\n:candy:\n[/quote]\n mmmm",
        )
      end

      it "doesn't award a badge when the emoji is in a quote" do
        cpp.grant_badges
        expect(post.user.user_badges.where(badge_id: Badge::FirstEmoji).exists?).to eq(false)
      end
    end

    context "with emoji in the text" do
      let(:post) do
        Fabricate(:post, user: user_with_auto_groups, raw: "time to eat some sweet :candy: mmmm")
      end

      it "awards a badge for using an emoji" do
        cpp.grant_badges
        expect(post.user.user_badges.where(badge_id: Badge::FirstEmoji).exists?).to eq(true)
      end
    end

    context "with onebox" do
      before do
        Oneboxer.stubs(:onebox).with(anything, anything).returns(nil)
        Oneboxer
          .stubs(:onebox)
          .with("https://discourse.org", anything)
          .returns("<aside class=\"onebox allowlistedgeneric\">the rest of the onebox</aside>")
      end

      it "awards the badge for using an onebox" do
        post =
          Fabricate(
            :post,
            user: user_with_auto_groups,
            raw: "onebox me:\n\nhttps://discourse.org\n",
          )
        cpp = CookedPostProcessor.new(post)
        cpp.post_process_oneboxes
        cpp.grant_badges
        expect(post.user.user_badges.where(badge_id: Badge::FirstOnebox).exists?).to eq(true)
      end

      it "does not award the badge when link is not oneboxed" do
        post =
          Fabricate(:post, user: user_with_auto_groups, raw: "onebox me:\n\nhttp://example.com\n")
        cpp = CookedPostProcessor.new(post)
        cpp.post_process_oneboxes
        cpp.grant_badges
        expect(post.user.user_badges.where(badge_id: Badge::FirstOnebox).exists?).to eq(false)
      end

      it "does not award the badge when the badge is disabled" do
        Badge.where(id: Badge::FirstOnebox).update_all(enabled: false)
        post =
          Fabricate(
            :post,
            user: user_with_auto_groups,
            raw: "onebox me:\n\nhttps://discourse.org\n",
          )
        cpp = CookedPostProcessor.new(post)
        cpp.post_process_oneboxes
        cpp.grant_badges
        expect(post.user.user_badges.where(badge_id: Badge::FirstOnebox).exists?).to eq(false)
      end
    end

    context "with reply_by_email" do
      let(:post) do
        Fabricate(
          :post,
          user: user_with_auto_groups,
          raw: "This is a **reply** via email ;)",
          via_email: true,
          post_number: 2,
        )
      end

      it "awards a badge for replying via email" do
        cpp.grant_badges
        expect(post.user.user_badges.where(badge_id: Badge::FirstReplyByEmail).exists?).to eq(true)
      end
    end
  end

  describe "quote processing" do
    let(:cpp) { CookedPostProcessor.new(cp) }
    let(:pp) do
      Fabricate(:post, user: user_with_auto_groups, raw: "This post is ripe for quoting!")
    end

    context "with an unmodified quote" do
      let(:cp) { Fabricate(:post, raw: <<~MARKDOWN) }
        [quote="#{pp.user.username}, post: #{pp.post_number}, topic:#{pp.topic_id}"]
        ripe for quoting
        [/quote]
        test
      MARKDOWN

      it "is not marked as modified" do
        cpp.post_process_quotes
        expect(cpp.doc.css("aside.quote.quote-modified")).to be_blank
      end
    end

    context "with a modified quote" do
      let(:cp) { Fabricate(:post, raw: <<~MARKDOWN) }
        [quote="#{pp.user.username}, post: #{pp.post_number}, topic:#{pp.topic_id}"]
        modified
        [/quote]
        test
      MARKDOWN

      it "is marked as modified" do
        cpp.post_process_quotes
        expect(cpp.doc.css("aside.quote.quote-modified")).to be_present
      end
    end

    context "with external discourse instance quote" do
      let(:cp) { Fabricate(:post, user: user_with_auto_groups, raw: <<~MARKDOWN.strip) }
        [quote="random_guy_not_from_our_discourse, post:2004, topic:401"]
        this quote is not from our discourse
        [/quote]
        and this is a reply
      MARKDOWN

      it "is marked as missing" do
        cpp.post_process_quotes
        expect(cpp.doc.css("aside.quote.quote-post-not-found")).to be_present
      end
    end
  end

  describe "full quote on direct reply" do
    fab!(:topic)
    let!(:post) do
      Fabricate(:post, user: user_with_auto_groups, topic: topic, raw: 'this is the "first" post')
    end

    let(:raw) { <<~RAW.strip }
      [quote="#{post.user.username}, post:#{post.post_number}, topic:#{topic.id}"]

      this is the “first” post

      [/quote]

      and this is the third reply
      RAW

    let(:raw2) { <<~RAW.strip }
      and this is the third reply

      [quote="#{post.user.username}, post:#{post.post_number}, topic:#{topic.id}"]
      this is the ”first” post
      [/quote]
      RAW

    let(:raw3) { <<~RAW.strip }
      [quote="#{post.user.username}, post:#{post.post_number}, topic:#{topic.id}"]

      this is the “first” post

      [/quote]

      [quote="#{post.user.username}, post:#{post.post_number}, topic:#{topic.id}"]

      this is the “first” post

      [/quote]

      and this is the third reply
      RAW

    before { SiteSetting.remove_full_quote = true }

    it "removes full quotes while preserving intervening posts" do
      hidden =
        Fabricate(
          :post,
          user: user_with_auto_groups,
          topic: topic,
          hidden: true,
          raw: "this is the second post after",
        )
      small_action =
        Fabricate(
          :post,
          user: user_with_auto_groups,
          topic: topic,
          post_type: Post.types[:small_action],
        )
      reply = Fabricate(:post, user: user_with_auto_groups, topic: topic, raw: raw)

      freeze_time do
        topic.bumped_at = 1.day.ago
        CookedPostProcessor.new(reply).remove_full_quote_on_direct_reply

        expect(topic.ordered_posts.pluck(:id)).to eq(
          [post.id, hidden.id, small_action.id, reply.id],
        )

        expect(topic.bumped_at).to eq_time(1.day.ago)
        expect(reply.raw).to eq("and this is the third reply")
        expect(reply.revisions.count).to eq(1)
        expect(reply.revisions.first.modifications["raw"]).to eq([raw, reply.raw])
        expect(reply.revisions.first.modifications["edit_reason"][1]).to eq(
          I18n.t(:removed_direct_reply_full_quotes),
        )
      end
    end

    it "does nothing if there are multiple quotes" do
      reply = Fabricate(:post, user: user_with_auto_groups, topic: topic, raw: raw3)
      CookedPostProcessor.new(reply).remove_full_quote_on_direct_reply
      expect(topic.ordered_posts.pluck(:id)).to eq([post.id, reply.id])
      expect(reply.raw).to eq(raw3)
    end

    it "does not delete quote if not first paragraph" do
      reply = Fabricate(:post, user: user_with_auto_groups, topic: topic, raw: raw2)
      CookedPostProcessor.new(reply).remove_full_quote_on_direct_reply
      expect(topic.ordered_posts.pluck(:id)).to eq([post.id, reply.id])
      expect(reply.raw).to eq(raw2)
    end

    it "does nothing when 'remove_full_quote' is disabled" do
      SiteSetting.remove_full_quote = false

      reply = Fabricate(:post, user: user_with_auto_groups, topic: topic, raw: raw)

      CookedPostProcessor.new(reply).remove_full_quote_on_direct_reply
      expect(reply.raw).to eq(raw)
    end

    it "does not generate a blank HTML document" do
      post = Fabricate(:post, user: user_with_auto_groups, topic: topic, raw: "<sunday><monday>")
      cp = CookedPostProcessor.new(post)
      cp.post_process
      expect(cp.html).to eq("<p></p>")
    end

    it "works only on new posts" do
      Fabricate(
        :post,
        user: user_with_auto_groups,
        topic: topic,
        hidden: true,
        raw: "this is the second post after",
      )
      Fabricate(
        :post,
        user: user_with_auto_groups,
        topic: topic,
        post_type: Post.types[:small_action],
      )
      reply = PostCreator.create!(topic.user, topic_id: topic.id, raw: raw)

      stub_image_size
      CookedPostProcessor.new(reply).post_process
      expect(reply.raw).to eq(raw)

      PostRevisor.new(reply).revise!(
        Discourse.system_user,
        raw: raw,
        edit_reason: "put back full quote",
      )

      stub_image_size
      CookedPostProcessor.new(reply).post_process(new_post: true)
      expect(reply.raw).to eq("and this is the third reply")
    end

    it "works with nested quotes" do
      reply1 = Fabricate(:post, user: user_with_auto_groups, topic: topic, raw: raw)
      reply2 = Fabricate(:post, user: user_with_auto_groups, topic: topic, raw: <<~RAW.strip)
        [quote="#{reply1.user.username}, post:#{reply1.post_number}, topic:#{topic.id}"]
        #{raw}
        [/quote]

        quoting a post with a quote
      RAW

      CookedPostProcessor.new(reply2).remove_full_quote_on_direct_reply
      expect(reply2.raw).to eq("quoting a post with a quote")
    end
  end

  describe "full quote on direct reply with full name prioritization" do
    fab!(:user) { Fabricate(:user, name: "james, john, the third", refresh_auto_groups: true) }
    fab!(:topic)
    let!(:post) { Fabricate(:post, user: user, topic: topic, raw: 'this is the "first" post') }

    let(:raw) { <<~RAW.strip }
      [quote="#{post.user.name}, post:#{post.post_number}, topic:#{topic.id}, username:#{post.user.username}"]

      this is the “first” post

      [/quote]

      and this is the third reply
      RAW

    let(:raw2) { <<~RAW.strip }
      and this is the third reply

      [quote="#{post.user.name}, post:#{post.post_number}, topic:#{topic.id}, username:#{post.user.username}"]
      this is the ”first” post
      [/quote]
      RAW

    let(:raw3) { <<~RAW.strip }
      [quote="#{post.user.name}, post:#{post.post_number}, topic:#{topic.id}, username:#{post.user.username}"]

      this is the “first” post

      [/quote]

      [quote="#{post.user.name}, post:#{post.post_number}, topic:#{topic.id}, username:#{post.user.username}"]

      this is the “first” post

      [/quote]

      and this is the third reply
      RAW

    before do
      SiteSetting.remove_full_quote = true
      SiteSetting.display_name_on_posts = true
      SiteSetting.prioritize_username_in_ux = false
    end

    it "removes direct reply with full quotes" do
      hidden =
        Fabricate(
          :post,
          user: user_with_auto_groups,
          topic: topic,
          hidden: true,
          raw: "this is the second post after",
        )
      small_action =
        Fabricate(
          :post,
          user: user_with_auto_groups,
          topic: topic,
          post_type: Post.types[:small_action],
        )
      reply = Fabricate(:post, user: user_with_auto_groups, topic: topic, raw: raw)

      freeze_time do
        topic.bumped_at = 1.day.ago
        CookedPostProcessor.new(reply).remove_full_quote_on_direct_reply

        expect(topic.ordered_posts.pluck(:id)).to eq(
          [post.id, hidden.id, small_action.id, reply.id],
        )

        expect(topic.bumped_at).to eq_time(1.day.ago)
        expect(reply.raw).to eq("and this is the third reply")
        expect(reply.revisions.count).to eq(1)
        expect(reply.revisions.first.modifications["raw"]).to eq([raw, reply.raw])
        expect(reply.revisions.first.modifications["edit_reason"][1]).to eq(
          I18n.t(:removed_direct_reply_full_quotes),
        )
      end
    end

    it "does nothing if there are multiple quotes" do
      reply = Fabricate(:post, user: user_with_auto_groups, topic: topic, raw: raw3)
      CookedPostProcessor.new(reply).remove_full_quote_on_direct_reply
      expect(topic.ordered_posts.pluck(:id)).to eq([post.id, reply.id])
      expect(reply.raw).to eq(raw3)
    end

    it "does not delete quote if not first paragraph" do
      reply = Fabricate(:post, user: user_with_auto_groups, topic: topic, raw: raw2)
      CookedPostProcessor.new(reply).remove_full_quote_on_direct_reply
      expect(topic.ordered_posts.pluck(:id)).to eq([post.id, reply.id])
      expect(reply.raw).to eq(raw2)
    end

    it "does nothing when 'remove_full_quote' is disabled" do
      SiteSetting.remove_full_quote = false

      reply = Fabricate(:post, user: user_with_auto_groups, topic: topic, raw: raw)

      CookedPostProcessor.new(reply).remove_full_quote_on_direct_reply
      expect(reply.raw).to eq(raw)
    end

    it "does not generate a blank HTML document" do
      post = Fabricate(:post, user: user_with_auto_groups, topic: topic, raw: "<sunday><monday>")
      cp = CookedPostProcessor.new(post)
      cp.post_process
      expect(cp.html).to eq("<p></p>")
    end

    it "works only on new posts" do
      Fabricate(
        :post,
        user: user_with_auto_groups,
        topic: topic,
        hidden: true,
        raw: "this is the second post after",
      )
      Fabricate(
        :post,
        user: user_with_auto_groups,
        topic: topic,
        post_type: Post.types[:small_action],
      )
      reply = PostCreator.create!(topic.user, topic_id: topic.id, raw: raw)

      stub_image_size
      CookedPostProcessor.new(reply).post_process
      expect(reply.raw).to eq(raw)

      PostRevisor.new(reply).revise!(
        Discourse.system_user,
        raw: raw,
        edit_reason: "put back full quote",
      )

      stub_image_size
      CookedPostProcessor.new(reply).post_process(new_post: true)
      expect(reply.raw).to eq("and this is the third reply")
    end

    it "works with nested quotes" do
      reply1 = Fabricate(:post, user: user, topic: topic, raw: raw)
      reply2 = Fabricate(:post, user: user_with_auto_groups, topic: topic, raw: <<~RAW.strip)
        [quote="#{reply1.user.name}, post:#{reply1.post_number}, topic:#{topic.id}, username:#{reply1.user.username}"]
        #{raw}
        [/quote]

        quoting a post with a quote
      RAW

      CookedPostProcessor.new(reply2).remove_full_quote_on_direct_reply
      expect(reply2.raw).to eq("quoting a post with a quote")
    end
  end

  describe "prioritizes full name in quotes" do
    fab!(:user) { Fabricate(:user, name: "james, john, the third", refresh_auto_groups: true) }
    fab!(:topic)
    let!(:post) { Fabricate(:post, user: user, topic: topic, raw: 'this is the "first" post') }

    before do
      SiteSetting.display_name_on_posts = true
      SiteSetting.prioritize_username_in_ux = false
    end

    it "maintains full name post processing" do
      reply = Fabricate(:post, user: user, topic: topic, raw: <<~RAW.strip)
        [quote="#{user.name}, post:#{post.id}, topic:#{topic.id}, username:#{user.username}"]
          quoting a post with a quote
        [/quote]

        quoting a post with a quote
      RAW
      doc = Nokogiri::HTML5.fragment(CookedPostProcessor.new(reply).html)
      expect(doc.css(".title").text).to eq("\n\n #{user.name}:")
    end
  end

  describe "#html" do
    it "escapes html entities in attributes per html5" do
      post = Fabricate(:post, user: user_with_auto_groups, raw: '<img alt="&<something>">')
      expect(post.cook(post.raw)).to eq('<p><img alt="&amp;<something>"></p>')
      expect(CookedPostProcessor.new(post).html).to eq('<p><img alt="&amp;<something>"></p>')
    end
  end

  describe "#post_process_videos" do
    fab!(:video_upload) { Fabricate(:upload, extension: "mp4") }
    fab!(:optimized_video_upload) { Fabricate(:upload, extension: "mp4") }
    fab!(:optimized_video) do
      Fabricate(:optimized_video, upload: video_upload, optimized_upload: optimized_video_upload)
    end

    let(:post) { Fabricate(:post, user: user_with_auto_groups, raw: <<~RAW) }
        <div class="video-placeholder-container" data-video-src="#{video_upload.url}">
          <div class="video-placeholder">
            <div class="video-placeholder-error">
              <div class="video-placeholder-error-content">
                <span class="video-placeholder-error-text">Video processing...</span>
              </div>
            </div>
          </div>
        </div>
      RAW

    let(:cpp) { CookedPostProcessor.new(post) }

    before do
      # Add video extensions to authorized extensions
      extensions = SiteSetting.authorized_extensions.split("|")
      SiteSetting.authorized_extensions = (extensions | %w[mp4 mov avi mkv]).join("|")
    end

    context "when CDN is not configured" do
      before do
        SiteSetting.s3_cdn_url = ""
        Rails.configuration.action_controller.stubs(:asset_host).returns(nil)
      end

      it "uses the original optimized video URL without CDN" do
        cpp.send(:post_process_videos)

        doc = Nokogiri::HTML5.fragment(cpp.html)
        container = doc.css(".video-placeholder-container").first
        expect(container["data-video-src"]).to eq(optimized_video_upload.url)
        expect(container["data-original-video-src"]).to eq(video_upload.url)
      end
    end

    context "when S3 CDN is configured" do
      before do
        setup_s3
        SiteSetting.s3_cdn_url = "https://s3-cdn.example.com"
        SiteSetting.enable_s3_uploads = true
        SiteSetting.authorized_extensions = "png|jpg|gif|mov|ogg|mp4|"

        # Ensure we're using S3Store
        store = FileStore::S3Store.new
        Discourse.stubs(:store).returns(store)

        # Update uploads to use S3 URLs that match the store's absolute_base_url
        base_url = Discourse.store.absolute_base_url
        video_upload.update!(url: "#{base_url}/original/1X/#{video_upload.sha1}.mp4")
        optimized_video_upload.update!(
          url: "#{base_url}/original/1X/#{optimized_video_upload.sha1}.mp4",
        )
      end

      it "uses CDN URL for optimized video" do
        cpp.send(:post_process_videos)

        doc = Nokogiri::HTML5.fragment(cpp.html)
        container = doc.css(".video-placeholder-container").first
        expected_cdn_url =
          "https://s3-cdn.example.com/original/1X/#{optimized_video_upload.sha1}.mp4"
        expect(container["data-video-src"]).to eq(expected_cdn_url)
        expect(container["data-original-video-src"]).to eq(video_upload.url)
      end
    end

    context "when local CDN is configured" do
      before do
        Rails.configuration.action_controller.stubs(:asset_host).returns("https://cdn.example.com")
      end

      it "uses local CDN URL for optimized video" do
        cpp.send(:post_process_videos)

        doc = Nokogiri::HTML5.fragment(cpp.html)
        container = doc.css(".video-placeholder-container").first
        expected_cdn_url = "https://cdn.example.com#{optimized_video_upload.url}"
        expect(container["data-video-src"]).to eq(expected_cdn_url)
        expect(container["data-original-video-src"]).to eq(video_upload.url)
      end
    end

    context "when no optimized video exists" do
      before { optimized_video.destroy }

      it "does not modify the video container" do
        cpp.send(:post_process_videos)

        doc = Nokogiri::HTML5.fragment(cpp.html)
        container = doc.css(".video-placeholder-container").first
        expect(container["data-video-src"]).to eq(video_upload.url)
        expect(container["data-original-video-src"]).to be_nil
      end
    end

    context "when optimized video URL is the same as original" do
      before { optimized_video_upload.update!(url: video_upload.url) }

      it "does not update the container" do
        cpp.send(:post_process_videos)

        doc = Nokogiri::HTML5.fragment(cpp.html)
        container = doc.css(".video-placeholder-container").first
        expect(container["data-video-src"]).to eq(video_upload.url)
        expect(container["data-original-video-src"]).to be_nil
      end
    end

    context "when video container has no data-video-src" do
      let(:post) { Fabricate(:post, user: user_with_auto_groups, raw: <<~RAW) }
          <div class="video-placeholder-container">
            <div class="video-placeholder">
              <div class="video-placeholder-error">
                <div class="video-placeholder-error-content">
                  <span class="video-placeholder-error-text">Video processing...</span>
                </div>
              </div>
            </div>
          </div>
        RAW

      it "skips processing the container" do
        cpp.send(:post_process_videos)

        doc = Nokogiri::HTML5.fragment(cpp.html)
        container = doc.css(".video-placeholder-container").first
        expect(container["data-video-src"]).to be_nil
        expect(container["data-original-video-src"]).to be_nil
      end
    end

    context "when upload cannot be found from URL" do
      before { video_upload.update!(url: "//different-bucket.s3.amazonaws.com/nonexistent.mp4") }

      it "does not modify the video container" do
        cpp.send(:post_process_videos)

        doc = Nokogiri::HTML5.fragment(cpp.html)
        container = doc.css(".video-placeholder-container").first
        expect(container["data-video-src"]).to eq(video_upload.url)
        expect(container["data-original-video-src"]).to be_nil
      end
    end

    context "when CDN URL is already present in optimized video URL" do
      before do
        SiteSetting.s3_cdn_url = "https://s3-cdn.example.com"
        optimized_video_upload.update!(
          url: "https://s3-cdn.example.com/original/1X/#{optimized_video_upload.sha1}.mp4",
        )
      end

      it "does not double-apply CDN URL" do
        cpp.send(:post_process_videos)

        doc = Nokogiri::HTML5.fragment(cpp.html)
        container = doc.css(".video-placeholder-container").first
        expect(container["data-video-src"]).to eq(optimized_video_upload.url)
        expect(container["data-original-video-src"]).to eq(video_upload.url)
      end
    end
  end
end
