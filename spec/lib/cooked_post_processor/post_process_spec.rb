# frozen_string_literal: true

require "cooked_post_processor"
require "file_store/s3_store"

RSpec.describe CookedPostProcessor, "#post_process" do
  fab!(:upload)
  fab!(:large_image_upload)
  fab!(:user_with_auto_groups) { Fabricate(:user, refresh_auto_groups: true) }
  let(:upload_path) { Discourse.store.upload_path }

  fab!(:post) { Fabricate(:post, user: user_with_auto_groups, raw: <<~RAW) }
      <img src="#{upload.url}">
      RAW

  let(:cpp) { CookedPostProcessor.new(post, disable_dominant_color: true) }
  let(:post_process) { sequence("post_process") }

  it "post process in sequence" do
    cpp.expects(:post_process_oneboxes).in_sequence(post_process)
    cpp.expects(:post_process_images).in_sequence(post_process)
    cpp.expects(:optimize_urls).in_sequence(post_process)
    cpp.post_process

    expect(UploadReference.exists?(target: post, upload: upload)).to eq(true)
  end

  describe "when post contains oneboxes and inline oneboxes" do
    let(:url_hostname) { "meta.discourse.org" }

    let(:url) { "https://#{url_hostname}/t/mini-inline-onebox-support-rfc/66400" }

    let(:not_oneboxed_url) { "https://#{url_hostname}/t/random-url" }

    let(:title) { "some title" }

    let(:post) { Fabricate(:post, user: user_with_auto_groups, raw: <<~RAW) }
        #{url}
        This is a #{url} with path

        #{not_oneboxed_url}

        This is a https://#{url_hostname}/t/another-random-url test
        This is a #{url} with path

        #{url}
        RAW

    before do
      SiteSetting.enable_inline_onebox_on_all_domains = true
      Oneboxer.stubs(:cached_onebox).with(url).returns <<~HTML
          <aside class="onebox allowlistedgeneric" data-onebox-src="https://meta.discourse.org/t/mini-inline-onebox-support-rfc/66400">
            <header class="source">
              <a href="https://meta.discourse.org/t/mini-inline-onebox-support-rfc/66400" target="_blank" rel="noopener">meta.discourse.org</a>
            </header>
            <article class="onebox-body">
              <h3><a href="https://meta.discourse.org/t/mini-inline-onebox-support-rfc/66400" target="_blank" rel="noopener">some title</a></h3>
              <p>some description</p>
            </article>
            <div class="onebox-metadata"></div>
            <div style="clear: both"></div>
          </aside>
        HTML
      Oneboxer.stubs(:cached_onebox).with(not_oneboxed_url).returns(nil)

      %i[head get].each { |method| stub_request(method, url).to_return(status: 200, body: <<~RAW) }
            <html>
              <head>
                <title>#{title}</title>
                <meta property='og:title' content="#{title}">
                <meta property='og:description' content="some description">
              </head>
            </html>
            RAW
    end

    after do
      InlineOneboxer.invalidate(url)
      Oneboxer.invalidate(url)
    end

    it "respects SiteSetting.max_oneboxes_per_post" do
      SiteSetting.max_oneboxes_per_post = 2
      SiteSetting.add_rel_nofollow_to_user_content = false

      cpp.post_process

      expect(cpp.html).to have_tag(
        "a",
        with: {
          href: url,
          class: "inline-onebox",
        },
        text: title,
        count: 2,
      )

      expect(cpp.html).to have_tag("aside.onebox a", text: title, count: 1)

      expect(cpp.html).to have_tag("aside.onebox a", text: url_hostname, count: 1)

      expect(cpp.html).to have_tag(
        "a",
        without: {
          class: "inline-onebox-loading",
        },
        text: not_oneboxed_url,
        count: 1,
      )

      expect(cpp.html).to have_tag(
        "a",
        without: {
          class: "onebox",
        },
        text: not_oneboxed_url,
        count: 1,
      )
    end
  end

  describe "when post contains inline oneboxes" do
    before { SiteSetting.enable_inline_onebox_on_all_domains = true }

    describe "internal links" do
      fab!(:topic)
      fab!(:post) { Fabricate(:post, user: user_with_auto_groups, raw: "Hello #{topic.url}") }
      let(:url) { topic.url }

      it "includes the topic title" do
        cpp.post_process

        expect(cpp.html).to have_tag(
          "a",
          with: {
            href: UrlHelper.cook_url(url),
          },
          without: {
            class: "inline-onebox-loading",
          },
          text: topic.title,
          count: 1,
        )

        topic.update!(title: "Updated to something else")
        cpp = CookedPostProcessor.new(post, invalidate_oneboxes: true)
        cpp.post_process

        expect(cpp.html).to have_tag(
          "a",
          with: {
            href: UrlHelper.cook_url(url),
          },
          without: {
            class: "inline-onebox-loading",
          },
          text: topic.title,
          count: 1,
        )
      end
    end

    describe "external links" do
      let(:url_with_path) { "https://meta.discourse.org/t/mini-inline-onebox-support-rfc/66400" }

      let(:url_with_query_param) { "https://meta.discourse.org?a" }

      let(:url_no_path) { "https://meta.discourse.org/" }

      let(:urls) { [url_with_path, url_with_query_param, url_no_path] }

      let(:title) { "<b>some title</b>" }
      let(:escaped_title) { CGI.escapeHTML(title) }

      let(:post) { Fabricate(:post, user: user_with_auto_groups, raw: <<~RAW) }
          This is a #{url_with_path} topic
          This should not be inline #{url_no_path} oneboxed

          - #{url_with_path}


             - #{url_with_query_param}
          RAW

      let(:staff_post) { Fabricate(:post, user: Fabricate(:admin), raw: <<~RAW) }
          This is a #{url_with_path} topic
          RAW

      before do
        urls.each do |url|
          stub_request(:get, url).to_return(
            status: 200,
            body: "<html><head><title>#{escaped_title}</title></head></html>",
          )
        end
      end

      after { urls.each { |url| InlineOneboxer.invalidate(url) } }

      it "converts the right links to inline oneboxes" do
        cpp.post_process
        html = cpp.html

        expect(html).to_not have_tag(
          "a",
          with: {
            href: url_no_path,
          },
          without: {
            class: "inline-onebox-loading",
          },
          text: title,
        )

        expect(html).to have_tag(
          "a",
          with: {
            href: url_with_path,
          },
          without: {
            class: "inline-onebox-loading",
          },
          text: title,
          count: 2,
        )

        expect(html).to have_tag(
          "a",
          with: {
            href: url_with_query_param,
          },
          without: {
            class: "inline-onebox-loading",
          },
          text: title,
          count: 1,
        )

        expect(html).to have_tag("a[rel='noopener nofollow ugc']")
      end

      it "removes nofollow if user is staff/tl3" do
        cpp = CookedPostProcessor.new(staff_post, invalidate_oneboxes: true)
        cpp.post_process
        expect(cpp.html).to_not have_tag("a[rel='noopener nofollow ugc']")
      end
    end

    describe "engine-supplied css_class" do
      let(:url) { "https://example.com/foo" }
      let(:post) { Fabricate(:post, user: user_with_auto_groups, raw: "Look at #{url} today") }
      let(:cpp) { CookedPostProcessor.new(post, invalidate_oneboxes: true) }

      before do
        allow(Oneboxer).to receive(:inline_data_for).with(url).and_return(
          title: "engine title",
          css_class: "--gh-status-merged",
        )
      end

      after { InlineOneboxer.invalidate(url) }

      it "adds the css_class alongside inline-onebox" do
        cpp.post_process

        link = Nokogiri::HTML5.fragment(cpp.html).at_css(%(a[href="#{url}"]))
        expect(link["class"]).to eq("inline-onebox --gh-status-merged")
        expect(link.text).to eq("engine title")
      end

      it "escapes HTML in engine-supplied title and css_class" do
        allow(Oneboxer).to receive(:inline_data_for).with(url).and_return(
          title: %(<script>alert("xss")</script>),
          css_class: %(broken" onerror="alert(1)),
        )

        cpp.post_process

        doc = Nokogiri::HTML5.fragment(cpp.html)
        link = doc.at_css(%(a[href="#{url}"]))

        expect(link.text).to eq(%(<script>alert("xss")</script>))
        expect(link["onerror"]).to be_nil
        expect(doc.css("script")).to be_empty
      end
    end
  end

  context "when processing images" do
    before { SiteSetting.responsive_post_image_sizes = "" }

    context "with responsive images" do
      before { SiteSetting.responsive_post_image_sizes = "1|1.5|3" }

      it "includes responsive images on demand" do
        upload.update!(width: 2000, height: 1500, filesize: 10_000, dominant_color: "FFFFFF")
        post = Fabricate(:post, user: user_with_auto_groups, raw: "hello <img src='#{upload.url}'>")

        # fake some optimized images
        OptimizedImage.create!(
          url: "/#{upload_path}/666x500.jpg",
          width: 666,
          height: 500,
          upload_id: upload.id,
          sha1: SecureRandom.hex,
          extension: ".jpg",
          filesize: 500,
          version: OptimizedImage::VERSION,
        )

        # fake 3x optimized image, we lose 2 pixels here over original due to rounding on downsize
        OptimizedImage.create!(
          url: "/#{upload_path}/1998x1500.jpg",
          width: 1998,
          height: 1500,
          upload_id: upload.id,
          sha1: SecureRandom.hex,
          extension: ".jpg",
          filesize: 800,
        )

        cpp = CookedPostProcessor.new(post)

        cpp.add_to_size_cache(upload.url, 2000, 1500)
        cpp.post_process

        html = cpp.html

        expect(html).to include(%Q|data-dominant-color="FFFFFF"|)
        # 1.5x is skipped cause we have a missing thumb
        expect(html).to include(
          "srcset=\"//test.localhost/#{upload_path}/666x500.jpg, //test.localhost/#{upload_path}/1998x1500.jpg 3x\"",
        )
        expect(html).to include("src=\"//test.localhost/#{upload_path}/666x500.jpg\"")

        # works with CDN
        set_cdn_url("http://cdn.localhost")

        cpp = CookedPostProcessor.new(post)
        cpp.add_to_size_cache(upload.url, 2000, 1500)
        cpp.post_process

        html = cpp.html

        expect(html).to include(%Q|data-dominant-color="FFFFFF"|)
        expect(html).to include(
          "srcset=\"//cdn.localhost/#{upload_path}/666x500.jpg, //cdn.localhost/#{upload_path}/1998x1500.jpg 3x\"",
        )
        expect(html).to include("src=\"//cdn.localhost/#{upload_path}/666x500.jpg\"")
      end

      it "doesn't include response images for cropped images" do
        upload.update!(width: 200, height: 4000, filesize: 12_345)
        post = Fabricate(:post, user: user_with_auto_groups, raw: "hello <img src='#{upload.url}'>")

        # fake some optimized images
        OptimizedImage.create!(
          url: "http://a.b.c/200x500.jpg",
          width: 200,
          height: 500,
          upload_id: upload.id,
          sha1: SecureRandom.hex,
          extension: ".jpg",
          filesize: 500,
        )

        cpp = CookedPostProcessor.new(post)
        cpp.add_to_size_cache(upload.url, 200, 4000)
        cpp.post_process

        expect(cpp.html).to_not include('srcset="')
      end
    end

    shared_examples "leave dimensions alone" do
      it "doesn't use them" do
        expect(cpp.html).to match(%r{src="http://foo.bar/image.png" width="" height=""})
        expect(cpp.html).to match(%r{src="http://domain.com/picture.jpg" width="50" height="42"})
        expect(cpp).to be_dirty
      end
    end

    context "with image_sizes" do
      fab!(:post) { Fabricate(:post_with_image_urls, user: user_with_auto_groups) }
      let(:cpp) { CookedPostProcessor.new(post, image_sizes: image_sizes) }

      before do
        stub_image_size
        cpp.post_process
      end

      context "when valid" do
        let(:image_sizes) { { "http://foo.bar/image.png" => { "width" => 111, "height" => 222 } } }

        it "uses them" do
          expect(cpp.html).to match(%r{src="http://foo.bar/image.png" width="111" height="222"})
          expect(cpp.html).to match(%r{src="http://domain.com/picture.jpg" width="50" height="42"})
          expect(cpp).to be_dirty
        end
      end

      context "with invalid width" do
        let(:image_sizes) { { "http://foo.bar/image.png" => { "width" => 0, "height" => 222 } } }

        include_examples "leave dimensions alone"
      end

      context "with invalid height" do
        let(:image_sizes) { { "http://foo.bar/image.png" => { "width" => 111, "height" => 0 } } }

        include_examples "leave dimensions alone"
      end

      context "with invalid width & height" do
        let(:image_sizes) { { "http://foo.bar/image.png" => { "width" => 0, "height" => 0 } } }

        include_examples "leave dimensions alone"
      end
    end

    context "with unsized images" do
      fab!(:upload) { Fabricate(:image_upload, width: 123, height: 456) }

      fab!(:post) { Fabricate(:post, user: user_with_auto_groups, raw: <<~HTML) }
          <img src="#{upload.url}">
          HTML

      let(:cpp) { CookedPostProcessor.new(post) }

      it "adds the width and height to images that don't have them" do
        cpp.post_process
        expect(cpp.html).to match(/width="123" height="456"/)
        expect(cpp).to be_dirty
      end
    end

    context "with small images" do
      fab!(:upload) { Fabricate(:image_upload, width: 150, height: 150) }
      fab!(:post) { Fabricate(:post, user: user_with_auto_groups, raw: <<~HTML) }
          <img src="#{upload.url}">
          HTML
      let(:cpp) { CookedPostProcessor.new(post, disable_dominant_color: true) }

      before { SiteSetting.create_thumbnails = true }

      it "shows the lightbox when both dimensions are above the minimum" do
        cpp.post_process
        expect(cpp.html).to match(/<div class="lightbox-wrapper">/)
      end

      it "does not show lightbox when both dimensions are below the minimum" do
        upload.update!(width: 50, height: 50)
        cpp.post_process

        expect(cpp.html).not_to match(/<div class="lightbox-wrapper">/)
      end

      it "does not show lightbox when either dimension is below the minimum" do
        upload.update!(width: 50, height: 150)
        cpp.post_process

        expect(cpp.html).not_to match(/<div class="lightbox-wrapper">/)
      end

      it "does not create thumbnails for small images" do
        Upload.any_instance.expects(:create_thumbnail!).never
        cpp.post_process
      end
    end

    context "with large images" do
      fab!(:upload) { Fabricate(:image_upload, width: 1750, height: 2000) }

      fab!(:post) { Fabricate(:post, user: user_with_auto_groups, raw: <<~HTML) }
          <img src="#{upload.url}">
          HTML

      let(:cpp) { CookedPostProcessor.new(post, disable_dominant_color: true) }

      before do
        SiteSetting.max_image_height = 2000
        SiteSetting.create_thumbnails = true
      end

      it "generates overlay information" do
        cpp.post_process

        expect(cpp.html).to match_html <<~HTML
            <p><div class="lightbox-wrapper"><a class="lightbox" href="//test.localhost#{upload.url}" data-download-href="//test.localhost/#{upload_path}/#{upload.sha1}" title="logo.png"><img src="//test.localhost#{upload.thumbnail(690, 788).url}" width="690" height="788"><div class="meta"><svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">logo.png</span><span class="informations">1750×2000 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg></div></a></div></p>
          HTML

        expect(cpp).to be_dirty
      end

      context "when image is inside onebox" do
        let(:url) { "https://image.com/my-avatar" }
        let(:post) { Fabricate(:post, user: user_with_auto_groups, raw: url) }

        before do
          Oneboxer
            .stubs(:onebox)
            .with(url, anything)
            .returns(
              "<img class='onebox' src='/#{upload_path}/original/1X/1234567890123456.jpg' />",
            )
        end

        it "does not add lightbox" do
          FastImage.expects(:size).returns([1750, 2000])

          cpp.post_process

          expect(cpp.html).to match_html <<~HTML
              <p><img class="onebox" src="//test.localhost/#{upload_path}/original/1X/1234567890123456.jpg" width="690" height="788"></p>
            HTML
        end
      end

      context "when image is an svg" do
        fab!(:post) do
          Fabricate(
            :post,
            user: user_with_auto_groups,
            raw: "<img src=\"/#{Discourse.store.upload_path}/original/1X/1234567890123456.svg\">",
          )
        end

        it "does not add lightbox" do
          FastImage.expects(:size).returns([1750, 2000])

          cpp.post_process

          expect(cpp.html).to match_html <<~HTML
              <p><img src="//test.localhost/#{upload_path}/original/1X/1234567890123456.svg" width="690" height="788"></p>
            HTML
        end

        it "does not add lightbox when the image source is a URL" do
          url = "http://test.discourse/#{upload_path}/original/1X/1234567890123456.svg?somepamas"
          url_post = Fabricate(:post, user: user_with_auto_groups, raw: "<img src=\"#{url}\">")
          processor = CookedPostProcessor.new(url_post, disable_dominant_color: true)
          FastImage.expects(:size).returns([1750, 2000])

          processor.post_process

          expect(processor.html).to match_html(
            "<p><img src=\"#{url}\" width=\"690\"\ height=\"788\"></p>",
          )
        end
      end
    end

    context "with s3_uploads" do
      let(:upload) { Fabricate(:secure_upload_s3) }

      before do
        setup_s3
        SiteSetting.s3_cdn_url = "https://s3.cdn.com"
        SiteSetting.authorized_extensions = "png|jpg|gif|mov|ogg|"

        stored_path = Discourse.store.get_path_for_upload(upload)
        upload.update_column(:url, "#{SiteSetting.Upload.absolute_base_url}/#{stored_path}")

        stub_upload(upload)

        SiteSetting.login_required = true
        SiteSetting.secure_uploads = true
      end

      let(:optimized_size) { "600x500" }

      let(:post) do
        Fabricate(
          :post,
          user: user_with_auto_groups,
          raw: "![large.png|#{optimized_size}](#{upload.short_url})",
        )
      end

      let(:secure_uploads_url) { "//test.localhost/secure-uploads/original/1X/#{upload.sha1}.png" }

      let(:cooked_html) { <<~HTML }
          <p><div class="lightbox-wrapper"><a class="lightbox" href="#{secure_uploads_url}" data-download-href="//test.localhost/uploads/short-url/#{upload.base62_sha1}.png?dl=1" title="large.png"><img src="#{secure_uploads_url}" alt="large.png" data-base62-sha1="#{upload.base62_sha1}" width="600" height="500"><div class="meta">
          <svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">large.png</span><span class="informations">#{upload.width}×#{upload.height} 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg>
          </div></a></div></p>
          HTML

      context "when the upload is attached to the correct post" do
        before do
          Discourse
            .store
            .class
            .any_instance
            .expects(:has_been_uploaded?)
            .at_least_once
            .returns(true)
          upload.update!(secure: true, access_control_post: post)
          post.link_post_uploads
        end

        it "handles secure images with the correct lightbox link href" do
          cpp.post_process

          expect(cpp.html).to match_html cooked_html
        end

        it "changes the secure status when the upload was not secure" do
          upload.update!(secure: false)
          cpp.post_process
          expect(upload.reload.secure).to eq(true)
        end

        it "changes the secure status when the upload is no longer secure" do
          SiteSetting.login_required = false
          cpp.post_process
          expect(upload.reload.secure).to eq(false)
        end

        it "does not use a secure URL when the upload is no longer secure" do
          SiteSetting.login_required = false
          SiteSetting.create_thumbnails = false
          SiteSetting.max_image_width = 10
          SiteSetting.max_image_height = 10

          cpp.post_process
          expect(cpp.html).not_to have_tag(
            "a",
            with: {
              class: "lightbox",
              href: "//test.localhost/secure-uploads/original/1X/#{upload.sha1}.png",
            },
          )
        end
      end

      context "when the upload is attached to a different post" do
        before do
          FastImage.size(upload.url)
          upload.update(
            secure: true,
            access_control_post: Fabricate(:post, user: user_with_auto_groups),
          )
        end

        it "does not create thumbnails or optimize images" do
          CookedPostProcessor.any_instance.expects(:optimize_image!).never
          Upload.any_instance.expects(:create_thumbnail!).never
          stub_image_size
          cpp.post_process

          expect(cpp.html).not_to match_html cooked_html
        end
      end
    end

    context "with tall images > default aspect ratio" do
      fab!(:upload) { Fabricate(:image_upload, width: 500, height: 2200) }

      fab!(:post) { Fabricate(:post, user: user_with_auto_groups, raw: <<~HTML) }
          <img src="#{upload.url}">
          HTML

      let(:cpp) { CookedPostProcessor.new(post, disable_dominant_color: true) }

      before { SiteSetting.create_thumbnails = true }

      it "resizes the image instead of crop" do
        cpp.post_process

        expect(cpp.html).to match(/width="113" height="500">/)
        expect(cpp).to be_dirty
      end
    end

    context "with taller images < default aspect ratio" do
      fab!(:upload) { Fabricate(:image_upload, width: 500, height: 2300) }

      fab!(:post) { Fabricate(:post, user: user_with_auto_groups, raw: <<~HTML) }
          <img src="#{upload.url}">
          HTML

      let(:cpp) { CookedPostProcessor.new(post, disable_dominant_color: true) }

      before { SiteSetting.create_thumbnails = true }

      it "crops the image" do
        cpp.post_process

        expect(cpp.html).to match(/width="500" height="500">/)
        expect(cpp).to be_dirty
      end
    end

    context "with iPhone X screenshots" do
      fab!(:upload) { Fabricate(:image_upload, width: 1125, height: 2436) }

      fab!(:post) { Fabricate(:post, user: user_with_auto_groups, raw: <<~HTML) }
          <img src="#{upload.url}">
          HTML

      let(:cpp) { CookedPostProcessor.new(post, disable_dominant_color: true) }

      before { SiteSetting.create_thumbnails = true }

      it "crops the image" do
        cpp.post_process

        expect(cpp.html).to match_html <<~HTML
            <p><div class="lightbox-wrapper"><a class="lightbox" href="//test.localhost#{upload.url}" data-download-href="//test.localhost/#{upload_path}/#{upload.sha1}" title="logo.png"><img src="//test.localhost#{upload.thumbnail(230, 500).url}" width="230" height="500"><div class="meta"><svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">logo.png</span><span class="informations">1125×2436 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg></div></a></div></p>
          HTML

        expect(cpp).to be_dirty
      end
    end

    context "with large images when using subfolders" do
      fab!(:upload) { Fabricate(:image_upload, width: 1750, height: 2000) }

      fab!(:post) { Fabricate(:post, user: user_with_auto_groups, raw: <<~HTML) }
          <img src="/subfolder#{upload.url}">
          HTML

      let(:cpp) { CookedPostProcessor.new(post, disable_dominant_color: true) }

      before do
        set_subfolder "/subfolder"
        stub_request(:get, "http://#{Discourse.current_hostname}/subfolder#{upload.url}").to_return(
          status: 200,
          body: File.new(Discourse.store.path_for(upload)),
        )

        SiteSetting.max_image_height = 2000
        SiteSetting.create_thumbnails = true
      end

      it "generates overlay information" do
        cpp.post_process

        expect(cpp.html).to match_html <<~HTML
            <p><div class="lightbox-wrapper"><a class="lightbox" href="//test.localhost/subfolder#{upload.url}" data-download-href="//test.localhost/subfolder/#{upload_path}/#{upload.sha1}" title="logo.png"><img src="//test.localhost#{upload.thumbnail(690, 788).url}" width="690" height="788"><div class="meta"><svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">logo.png</span><span class="informations">1750×2000 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg></div></a></div></p>
          HTML

        expect(cpp).to be_dirty
      end

      it "escapes the filename" do
        upload.update!(original_filename: "><img src=x onerror=alert('haha')>.png")
        cpp.post_process

        expect(cpp.html).to match_html <<~HTML
            <p><div class="lightbox-wrapper"><a class="lightbox" href="//test.localhost/subfolder#{upload.url}" data-download-href="//test.localhost/subfolder/#{upload_path}/#{upload.sha1}" title="><img src=x onerror=alert('haha')>.png"><img src="//test.localhost#{upload.thumbnail(690, 788).url}" width="690" height="788"><div class="meta"><svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">&gt;&lt;img src=x onerror=alert('haha')&gt;.png</span><span class="informations">1750×2000 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg></div></a></div></p>
          HTML
      end
    end

    context "with title and alt" do
      fab!(:upload) { Fabricate(:image_upload, width: 1750, height: 2000) }

      fab!(:post) { Fabricate(:post, user: user_with_auto_groups, raw: <<~HTML) }
          <img src="#{upload.url}" title="WAT" alt="RED">
          HTML

      let(:cpp) { CookedPostProcessor.new(post, disable_dominant_color: true) }

      before do
        SiteSetting.max_image_height = 2000
        SiteSetting.create_thumbnails = true
      end

      it "generates overlay information using image title and ignores alt" do
        cpp.post_process

        expect(cpp.html).to match_html <<~HTML
            <p><div class="lightbox-wrapper"><a class="lightbox" href="//test.localhost#{upload.url}" data-download-href="//test.localhost/#{upload_path}/#{upload.sha1}" title="WAT"><img src="//test.localhost#{upload.thumbnail(690, 788).url}" title="WAT" alt="RED" width="690" height="788"><div class="meta"><svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">WAT</span><span class="informations">1750×2000 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg></div></a></div></p>
          HTML

        expect(cpp).to be_dirty
      end
    end

    context "with title only" do
      fab!(:upload) { Fabricate(:image_upload, width: 1750, height: 2000) }

      fab!(:post) { Fabricate(:post, user: user_with_auto_groups, raw: <<~HTML) }
          <img src="#{upload.url}" title="WAT">
          HTML

      let(:cpp) { CookedPostProcessor.new(post, disable_dominant_color: true) }

      before do
        SiteSetting.max_image_height = 2000
        SiteSetting.create_thumbnails = true
      end

      it "generates overlay information using image title" do
        cpp.post_process

        expect(cpp.html).to match_html <<~HTML
            <p><div class="lightbox-wrapper"><a class="lightbox" href="//test.localhost#{upload.url}" data-download-href="//test.localhost/#{upload_path}/#{upload.sha1}" title="WAT"><img src="//test.localhost#{upload.thumbnail(690, 788).url}" title="WAT" width="690" height="788"><div class="meta"><svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">WAT</span><span class="informations">1750×2000 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg></div></a></div></p>
          HTML

        expect(cpp).to be_dirty
      end
    end

    context "with alt only" do
      fab!(:upload) { Fabricate(:image_upload, width: 1750, height: 2000) }

      fab!(:post) { Fabricate(:post, user: user_with_auto_groups, raw: <<~HTML) }
          <img src="#{upload.url}" alt="RED">
          HTML

      let(:cpp) { CookedPostProcessor.new(post, disable_dominant_color: true) }

      before do
        SiteSetting.max_image_height = 2000
        SiteSetting.create_thumbnails = true
      end

      it "generates overlay information using image alt" do
        cpp.post_process

        expect(cpp.html).to match_html <<~HTML
            <p><div class="lightbox-wrapper"><a class="lightbox" href="//test.localhost#{upload.url}" data-download-href="//test.localhost/#{upload_path}/#{upload.sha1}" title="RED"><img src="//test.localhost#{upload.thumbnail(690, 788).url}" alt="RED" width="690" height="788"><div class="meta"><svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">RED</span><span class="informations">1750×2000 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg></div></a></div></p>
          HTML

        expect(cpp).to be_dirty
      end
    end

    context "with topic image" do
      fab!(:post) { Fabricate(:post_with_uploaded_image, user: user_with_auto_groups) }
      let(:cpp) { CookedPostProcessor.new(post) }

      it "adds a topic image if there's one in the first post" do
        FastImage.stubs(:size)
        expect(post.topic.image_upload_id).to eq(nil)

        cpp.post_process
        post.topic.reload
        expect(post.topic.image_upload_id).to be_present
      end

      it "removes image if post is edited and no longer has an image" do
        FastImage.stubs(:size)

        cpp.post_process
        post.topic.reload
        expect(post.topic.image_upload_id).to be_present
        expect(post.image_upload_id).to be_present

        post.update!(raw: "This post no longer has an image.")
        CookedPostProcessor.new(post).post_process
        post.topic.reload
        expect(post.topic.image_upload_id).not_to be_present
        expect(post.image_upload_id).not_to be_present
      end

      it "generates thumbnails correctly" do
        # image size in cooked is 1500*2000
        topic = post.topic
        cpp.post_process
        topic.reload
        expect(topic.image_upload_id).to be_present
        expect(post.image_upload_id).to be_present

        post =
          Fabricate(
            :post,
            user: user_with_auto_groups,
            topic: topic,
            raw: "this post doesn't have an image",
          )
        CookedPostProcessor.new(post).post_process
        topic.reload

        expect(post.topic.image_upload_id).to be_present
        expect(post.image_upload_id).to be_blank
      end
    end

    context "with topic og image generation" do
      fab!(:post) { Fabricate(:post, user: user_with_auto_groups, raw: "no image in this post") }

      it "enqueues the generator job when the first post has no image and setting is on" do
        SiteSetting.generate_topic_og_image = true
        expect { CookedPostProcessor.new(post).post_process }.to change {
          Jobs::GenerateTopicOgImage.jobs.size
        }.by(1)
      end

      it "does not enqueue when the setting is off" do
        SiteSetting.generate_topic_og_image = false
        expect { CookedPostProcessor.new(post).post_process }.not_to change {
          Jobs::GenerateTopicOgImage.jobs.size
        }
      end

      it "does not enqueue when the topic already has a generated OG image" do
        SiteSetting.generate_topic_og_image = true
        post.topic.update_column(:og_image_upload_id, Fabricate(:upload).id)
        expect { CookedPostProcessor.new(post).post_process }.not_to change {
          Jobs::GenerateTopicOgImage.jobs.size
        }
      end

      it "does not enqueue for non-first posts" do
        SiteSetting.generate_topic_og_image = true
        reply =
          Fabricate(:post, user: user_with_auto_groups, topic: post.topic, raw: "no image reply")
        expect { CookedPostProcessor.new(reply).post_process }.not_to change {
          Jobs::GenerateTopicOgImage.jobs.size
        }
      end

      it "does not enqueue for personal messages" do
        SiteSetting.generate_topic_og_image = true
        pm_post = Fabricate(:private_message_post, user: user_with_auto_groups)
        expect { CookedPostProcessor.new(pm_post).post_process }.not_to change {
          Jobs::GenerateTopicOgImage.jobs.size
        }
      end

      it "does not enqueue for topics in a read-restricted category" do
        SiteSetting.generate_topic_og_image = true
        private_category = Fabricate(:private_category, group: Fabricate(:group))
        post.topic.update!(category: private_category)
        expect { CookedPostProcessor.new(post).post_process }.not_to change {
          Jobs::GenerateTopicOgImage.jobs.size
        }
      end

      it "clears the generated OG image when the first post has an image" do
        SiteSetting.generate_topic_og_image = true
        FastImage.stubs(:size)
        old_upload = Fabricate(:upload)
        image_post = Fabricate(:post_with_uploaded_image, user: user_with_auto_groups)
        image_post.topic.update_column(:og_image_upload_id, old_upload.id)
        UploadReference.ensure_exist!(upload_ids: [old_upload.id], target: image_post.topic)

        CookedPostProcessor.new(image_post).post_process

        expect(image_post.topic.reload.og_image_upload_id).to be_nil
        expect(UploadReference.exists?(upload_id: old_upload.id, target: image_post.topic)).to eq(
          false,
        )
      end
    end

    it "prioritizes data-thumbnail images" do
      upload1 = Fabricate(:image_upload, width: 1750, height: 2000)
      upload2 = Fabricate(:image_upload, width: 1750, height: 2000)
      post = Fabricate(:post, user: user_with_auto_groups, raw: <<~MD)
          ![alttext|1750x2000](#{upload1.url})
          ![alttext|1750x2000|thumbnail](#{upload2.url})
        MD

      CookedPostProcessor.new(post, disable_dominant_color: true).post_process

      expect(post.reload.image_upload_id).to eq(upload2.id)
    end

    context "with post image" do
      let(:reply) do
        Fabricate(:post_with_uploaded_image, user: user_with_auto_groups, post_number: 2)
      end
      let(:cpp) { CookedPostProcessor.new(reply) }

      it "adds a post image if there's one in the post" do
        FastImage.stubs(:size)
        expect(reply.image_upload_id).to eq(nil)
        cpp.post_process
        reply.reload
        expect(reply.image_upload_id).to be_present
      end

      context "when upload filename doesn't match SHA1" do
        let(:upload_with_secure_url) do
          Fabricate(
            :upload,
            sha1: "a" * 40,
            url: "/uploads/default/original/3X/b/c/#{"d" * 40}.png",
          )
        end
        let(:post_with_secure_upload) do
          Fabricate(
            :post,
            user: user_with_auto_groups,
            raw: "<img src='#{upload_with_secure_url.url}'>",
          )
        end
        let(:cpp) { CookedPostProcessor.new(post_with_secure_upload) }

        it "sets image_upload via URL fallback" do
          expect { cpp.post_process }.to change {
            post_with_secure_upload.reload.image_upload
          }.to eq(upload_with_secure_url)
        end
      end
    end
  end
end
