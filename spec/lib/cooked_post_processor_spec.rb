# frozen_string_literal: true

require "cooked_post_processor"
require "file_store/s3_store"

RSpec.describe CookedPostProcessor do
  fab!(:upload)
  fab!(:large_image_upload)
  fab!(:user_with_auto_groups) { Fabricate(:user, refresh_auto_groups: true) }
  let(:upload_path) { Discourse.store.upload_path }

  describe "#post_process" do
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

        %i[head get].each do |method|
          stub_request(method, url).to_return(status: 200, body: <<~RAW)
            <html>
              <head>
                <title>#{title}</title>
                <meta property='og:title' content="#{title}">
                <meta property='og:description' content="some description">
              </head>
            </html>
            RAW
        end
      end

      after do
        InlineOneboxer.invalidate(url)
        Oneboxer.invalidate(url)
      end

      it "should respect SiteSetting.max_oneboxes_per_post" do
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

        it "should convert the right links to inline oneboxes" do
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
    end

    context "when processing images" do
      before { SiteSetting.responsive_post_image_sizes = "" }

      context "with responsive images" do
        before { SiteSetting.responsive_post_image_sizes = "1|1.5|3" }

        it "includes responsive images on demand" do
          upload.update!(width: 2000, height: 1500, filesize: 10_000, dominant_color: "FFFFFF")
          post =
            Fabricate(:post, user: user_with_auto_groups, raw: "hello <img src='#{upload.url}'>")

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
          post =
            Fabricate(:post, user: user_with_auto_groups, raw: "hello <img src='#{upload.url}'>")

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
          let(:image_sizes) do
            { "http://foo.bar/image.png" => { "width" => 111, "height" => 222 } }
          end

          it "uses them" do
            expect(cpp.html).to match(%r{src="http://foo.bar/image.png" width="111" height="222"})
            expect(cpp.html).to match(
              %r{src="http://domain.com/picture.jpg" width="50" height="42"},
            )
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
          expect(cpp.html).to match_html <<~HTML
            <p><div class="lightbox-wrapper"><a class="lightbox" href="//test.localhost#{upload.url}" data-download-href="//test.localhost/#{upload_path}/#{upload.sha1}" title="logo.png"><img src="//test.localhost/#{upload_path}/original/1X/#{upload.sha1}.png" width="150" height="150"><div class="meta"><svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">logo.png</span><span class="informations">150×150 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg></div></a></div></p>
          HTML
        end

        it "does not show lightbox when both dimensions are below the minimum" do
          upload.update!(width: 50, height: 50)
          cpp.post_process

          expect(cpp.html).to match_html <<~HTML
            <p><img src="//test.localhost#{upload.url}" width="50" height="50"></p>
          HTML
        end

        it "does not show lightbox when either dimension is below the minimum" do
          upload.update!(width: 50, height: 150)
          cpp.post_process

          expect(cpp.html).to match_html <<~HTML
            <p><img src="//test.localhost#{upload.url}" width="50" height="150"></p>
          HTML
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
            <p><div class="lightbox-wrapper"><a class="lightbox" href="//test.localhost#{upload.url}" data-download-href="//test.localhost/#{upload_path}/#{upload.sha1}" title="logo.png"><img src="//test.localhost/#{upload_path}/optimized/1X/#{upload.sha1}_#{OptimizedImage::VERSION}_690x788.png" width="690" height="788"><div class="meta"><svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">logo.png</span><span class="informations">1750×2000 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg></div></a></div></p>
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

          it "should not add lightbox" do
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

          it "should not add lightbox" do
            FastImage.expects(:size).returns([1750, 2000])

            cpp.post_process

            expect(cpp.html).to match_html <<~HTML
              <p><img src="//test.localhost/#{upload_path}/original/1X/1234567890123456.svg" width="690" height="788"></p>
            HTML
          end

          context "when image src is an URL" do
            let(:post) do
              Fabricate(
                :post,
                user: user_with_auto_groups,
                raw:
                  "<img src=\"http://test.discourse/#{upload_path}/original/1X/1234567890123456.svg?somepamas\">",
              )
            end

            it "should not add lightbox" do
              FastImage.expects(:size).returns([1750, 2000])

              cpp.post_process

              expect(cpp.html).to match_html(
                "<p><img src=\"http://test.discourse/#{upload_path}/original/1X/1234567890123456.svg?somepamas\" width=\"690\"\ height=\"788\"></p>",
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

          let(:cooked_html) { <<~HTML }
            <p><div class="lightbox-wrapper"><a class="lightbox" href="//test.localhost/secure-uploads/original/1X/#{upload.sha1}.png" data-download-href="//test.localhost/uploads/short-url/#{upload.base62_sha1}.unknown?dl=1" title="large.png"><img src="" alt="large.png" data-base62-sha1="#{upload.base62_sha1}" width="600" height="500"><div class="meta">
            <svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">large.png</span><span class="informations">1750×2000 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg>
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

            # TODO fix this spec, it is sometimes getting CDN links when it runs concurrently
            xit "handles secure images with the correct lightbox link href" do
              FastImage.expects(:size).returns([1750, 2000])
              OptimizedImage.expects(:resize).returns(true)
              cpp.post_process

              expect(cpp.html).to match_html cooked_html
            end

            context "when the upload was not secure" do
              before { upload.update!(secure: false) }

              it "changes the secure status" do
                cpp.post_process
                expect(upload.reload.secure).to eq(true)
              end
            end

            context "when the upload should no longer be considered secure" do
              before { SiteSetting.login_required = false }

              it "changes the secure status" do
                cpp.post_process
                expect(upload.reload.secure).to eq(false)
              end

              it "does not use a secure-uploads URL for the lightbox href" do
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
            <p><div class="lightbox-wrapper"><a class="lightbox" href="//test.localhost#{upload.url}" data-download-href="//test.localhost/#{upload_path}/#{upload.sha1}" title="logo.png"><img src="//test.localhost/#{upload_path}/optimized/1X/#{upload.sha1}_#{OptimizedImage::VERSION}_230x500.png" width="230" height="500"><div class="meta"><svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">logo.png</span><span class="informations">1125×2436 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg></div></a></div></p>
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
          stub_request(
            :get,
            "http://#{Discourse.current_hostname}/subfolder#{upload.url}",
          ).to_return(status: 200, body: File.new(Discourse.store.path_for(upload)))

          SiteSetting.max_image_height = 2000
          SiteSetting.create_thumbnails = true
        end

        it "generates overlay information" do
          cpp.post_process

          expect(cpp.html).to match_html <<~HTML
            <p><div class="lightbox-wrapper"><a class="lightbox" href="//test.localhost/subfolder#{upload.url}" data-download-href="//test.localhost/subfolder/#{upload_path}/#{upload.sha1}" title="logo.png"><img src="//test.localhost/subfolder/#{upload_path}/optimized/1X/#{upload.sha1}_#{OptimizedImage::VERSION}_690x788.png" width="690" height="788"><div class="meta"><svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">logo.png</span><span class="informations">1750×2000 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg></div></a></div></p>
          HTML

          expect(cpp).to be_dirty
        end

        it "should escape the filename" do
          upload.update!(original_filename: "><img src=x onerror=alert('haha')>.png")
          cpp.post_process

          expect(cpp.html).to match_html <<~HTML
            <p><div class="lightbox-wrapper"><a class="lightbox" href="//test.localhost/subfolder#{upload.url}" data-download-href="//test.localhost/subfolder/#{upload_path}/#{upload.sha1}" title="><img src=x onerror=alert('haha')>.png"><img src="//test.localhost/subfolder/#{upload_path}/optimized/1X/#{upload.sha1}_#{OptimizedImage::VERSION}_690x788.png" width="690" height="788"><div class="meta"><svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">&gt;&lt;img src=x onerror=alert('haha')&gt;.png</span><span class="informations">1750×2000 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg></div></a></div></p>
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
            <p><div class="lightbox-wrapper"><a class="lightbox" href="//test.localhost#{upload.url}" data-download-href="//test.localhost/#{upload_path}/#{upload.sha1}" title="WAT"><img src="//test.localhost/#{upload_path}/optimized/1X/#{upload.sha1}_#{OptimizedImage::VERSION}_690x788.png" title="WAT" alt="RED" width="690" height="788"><div class="meta"><svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">WAT</span><span class="informations">1750×2000 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg></div></a></div></p>
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
            <p><div class="lightbox-wrapper"><a class="lightbox" href="//test.localhost#{upload.url}" data-download-href="//test.localhost/#{upload_path}/#{upload.sha1}" title="WAT"><img src="//test.localhost/#{upload_path}/optimized/1X/#{upload.sha1}_#{OptimizedImage::VERSION}_690x788.png" title="WAT" width="690" height="788"><div class="meta"><svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">WAT</span><span class="informations">1750×2000 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg></div></a></div></p>
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
            <p><div class="lightbox-wrapper"><a class="lightbox" href="//test.localhost#{upload.url}" data-download-href="//test.localhost/#{upload_path}/#{upload.sha1}" title="RED"><img src="//test.localhost/#{upload_path}/optimized/1X/#{upload.sha1}_#{OptimizedImage::VERSION}_690x788.png" alt="RED" width="690" height="788"><div class="meta"><svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">RED</span><span class="informations">1750×2000 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg></div></a></div></p>
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
      end
    end
  end

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

      it "marks giphy images as animated" do
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

      it "marks giphy images as animated" do
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
    it "generates a onebox-avatar class" do
      url = "https://square-image.com/onebox"

      body = <<~HTML
      <html>
      <head>
      <meta property='og:title' content="Page awesome">
      <meta property='og:image' content="https://image.com/avatar.png">
      <meta property='og:description' content="Page awesome desc">
      </head>
      </html>
      HTML

      stub_request(:head, url)
      stub_request(:get, url).to_return(body: body)

      # not an ideal stub but shipping the whole image to fast image can add
      # a lot of cost to this test
      stub_image_size(width: 200, height: 200)

      post = Fabricate.build(:post, raw: url)
      cpp = CookedPostProcessor.new(post, invalidate_oneboxes: true)

      cpp.post_process_oneboxes

      expect(cpp.doc.to_s).not_to include("aspect-image")
      expect(cpp.doc.to_s).to include("onebox-avatar")
    end
  end

  describe "#optimize_urls" do
    let(:post) { build(:post_with_uploads_and_links) }
    let(:cpp) { CookedPostProcessor.new(post) }

    it "uses schemaless url for uploads" do
      cpp.optimize_urls
      expect(cpp.html).to match_html <<~HTML
        <p><a href="//test.localhost/#{upload_path}/original/2X/2345678901234567.jpg">Link</a><br>
        <img src="//test.localhost/#{upload_path}/original/1X/1234567890123456.jpg"><br>
        <a href="http://www.google.com" rel="noopener nofollow ugc">Google</a><br>
        <img src="http://foo.bar/image.png"><br>
        <a class="attachment" href="//test.localhost/#{upload_path}/original/1X/af2c2618032c679333bebf745e75f9088748d737.txt">text.txt</a> (20 Bytes)<br>
        <img src="//test.localhost/images/emoji/twitter/smile.png?v=#{Emoji::EMOJI_VERSION}" title=":smile:" class="emoji only-emoji" alt=":smile:" loading="lazy" width="20" height="20"></p>
      HTML
    end

    context "when CDN is enabled" do
      it "uses schemaless CDN url for http uploads" do
        Rails.configuration.action_controller.stubs(:asset_host).returns("http://my.cdn.com")
        cpp.optimize_urls
        expect(cpp.html).to match_html <<~HTML
          <p><a href="//my.cdn.com/#{upload_path}/original/2X/2345678901234567.jpg">Link</a><br>
          <img src="//my.cdn.com/#{upload_path}/original/1X/1234567890123456.jpg"><br>
          <a href="http://www.google.com" rel="noopener nofollow ugc">Google</a><br>
          <img src="http://foo.bar/image.png"><br>
          <a class="attachment" href="//my.cdn.com/#{upload_path}/original/1X/af2c2618032c679333bebf745e75f9088748d737.txt">text.txt</a> (20 Bytes)<br>
          <img src="//my.cdn.com/images/emoji/twitter/smile.png?v=#{Emoji::EMOJI_VERSION}" title=":smile:" class="emoji only-emoji" alt=":smile:" loading="lazy" width="20" height="20"></p>
        HTML
      end

      it "doesn't use schemaless CDN url for https uploads" do
        Rails.configuration.action_controller.stubs(:asset_host).returns("https://my.cdn.com")
        cpp.optimize_urls
        expect(cpp.html).to match_html <<~HTML
          <p><a href="https://my.cdn.com/#{upload_path}/original/2X/2345678901234567.jpg">Link</a><br>
          <img src="https://my.cdn.com/#{upload_path}/original/1X/1234567890123456.jpg"><br>
          <a href="http://www.google.com" rel="noopener nofollow ugc">Google</a><br>
          <img src="http://foo.bar/image.png"><br>
          <a class="attachment" href="https://my.cdn.com/#{upload_path}/original/1X/af2c2618032c679333bebf745e75f9088748d737.txt">text.txt</a> (20 Bytes)<br>
          <img src="https://my.cdn.com/images/emoji/twitter/smile.png?v=#{Emoji::EMOJI_VERSION}" title=":smile:" class="emoji only-emoji" alt=":smile:" loading="lazy" width="20" height="20"></p>
        HTML
      end

      it "doesn't use CDN when login is required" do
        SiteSetting.login_required = true
        Rails.configuration.action_controller.stubs(:asset_host).returns("http://my.cdn.com")
        cpp.optimize_urls
        expect(cpp.html).to match_html <<~HTML
          <p><a href="//my.cdn.com/#{upload_path}/original/2X/2345678901234567.jpg">Link</a><br>
          <img src="//my.cdn.com/#{upload_path}/original/1X/1234567890123456.jpg"><br>
          <a href="http://www.google.com" rel="noopener nofollow ugc">Google</a><br>
          <img src="http://foo.bar/image.png"><br>
          <a class="attachment" href="//test.localhost/#{upload_path}/original/1X/af2c2618032c679333bebf745e75f9088748d737.txt">text.txt</a> (20 Bytes)<br>
          <img src="//my.cdn.com/images/emoji/twitter/smile.png?v=#{Emoji::EMOJI_VERSION}" title=":smile:" class="emoji only-emoji" alt=":smile:" loading="lazy" width="20" height="20"></p>
        HTML
      end

      it "doesn't use CDN when preventing anons from downloading files" do
        SiteSetting.prevent_anons_from_downloading_files = true
        Rails.configuration.action_controller.stubs(:asset_host).returns("http://my.cdn.com")
        cpp.optimize_urls
        expect(cpp.html).to match_html <<~HTML
          <p><a href="//my.cdn.com/#{upload_path}/original/2X/2345678901234567.jpg">Link</a><br>
          <img src="//my.cdn.com/#{upload_path}/original/1X/1234567890123456.jpg"><br>
          <a href="http://www.google.com" rel="noopener nofollow ugc">Google</a><br>
          <img src="http://foo.bar/image.png"><br>
          <a class="attachment" href="//test.localhost/#{upload_path}/original/1X/af2c2618032c679333bebf745e75f9088748d737.txt">text.txt</a> (20 Bytes)<br>
          <img src="//my.cdn.com/images/emoji/twitter/smile.png?v=#{Emoji::EMOJI_VERSION}" title=":smile:" class="emoji only-emoji" alt=":smile:" loading="lazy" width="20" height="20"></p>
        HTML
      end

      context "with s3_uploads" do
        before do
          Rails.configuration.action_controller.stubs(:asset_host).returns("https://local.cdn.com")

          setup_s3
          SiteSetting.s3_cdn_url = "https://s3.cdn.com"
          SiteSetting.authorized_extensions = "png|jpg|gif|mov|ogg|"

          uploaded_file = file_from_fixtures("smallest.png")
          upload_sha1 = Digest::SHA1.hexdigest(File.read(uploaded_file))

          upload.update!(
            original_filename: "smallest.png",
            width: 10,
            height: 20,
            sha1: upload_sha1,
            extension: "png",
          )
        end

        it "uses the right CDN when uploads are on S3" do
          stored_path = Discourse.store.get_path_for_upload(upload)
          upload.update_column(:url, "#{SiteSetting.Upload.absolute_base_url}/#{stored_path}")

          the_post =
            Fabricate(
              :post,
              user: user_with_auto_groups,
              raw:
                %Q{This post has a local emoji :+1: and an external upload\n\n![smallest.png|10x20](#{upload.short_url})},
            )

          cpp = CookedPostProcessor.new(the_post)
          cpp.optimize_urls

          expect(cpp.html).to match_html <<~HTML
            <p>This post has a local emoji <img src="https://local.cdn.com/images/emoji/twitter/+1.png?v=#{Emoji::EMOJI_VERSION}" title=":+1:" class="emoji" alt=":+1:" loading="lazy" width="20" height="20"> and an external upload</p>
            <p><img src="https://s3.cdn.com/#{stored_path}" alt="smallest.png" data-base62-sha1="#{upload.base62_sha1}" width="10" height="20"></p>
          HTML
        end

        it "doesn't use CDN for secure uploads" do
          SiteSetting.secure_uploads = true

          stored_path = Discourse.store.get_path_for_upload(upload)
          upload.update_column(:url, "#{SiteSetting.Upload.absolute_base_url}/#{stored_path}")
          upload.update_column(:secure, true)

          the_post =
            Fabricate(
              :post,
              user: user_with_auto_groups,
              raw:
                %Q{This post has a local emoji :+1: and an external upload\n\n![smallest.png|10x20](#{upload.short_url})},
            )

          cpp = CookedPostProcessor.new(the_post)
          cpp.optimize_urls

          expect(cpp.html).to match_html <<~HTML
            <p>This post has a local emoji <img src="https://local.cdn.com/images/emoji/twitter/+1.png?v=#{Emoji::EMOJI_VERSION}" title=":+1:" class="emoji" alt=":+1:" loading="lazy" width="20" height="20"> and an external upload</p>
            <p><img src="/secure-uploads/#{stored_path}" alt="smallest.png" data-base62-sha1="#{upload.base62_sha1}" width="10" height="20"></p>
          HTML
        end

        it "doesn't use the secure uploads URL for custom emoji" do
          CustomEmoji.create!(name: "trout", upload: upload)
          Emoji.clear_cache
          Emoji.load_custom
          stored_path = Discourse.store.get_path_for_upload(upload)
          upload.update_column(:url, "#{SiteSetting.Upload.absolute_base_url}/#{stored_path}")
          upload.update_column(:secure, true)

          the_post =
            Fabricate(
              :post,
              user: user_with_auto_groups,
              raw: "This post has a custom emoji :trout:",
            )
          the_post.cook(the_post.raw)

          cpp = CookedPostProcessor.new(the_post)
          cpp.optimize_urls

          upload_url = upload.url.gsub(SiteSetting.Upload.absolute_base_url, "https://s3.cdn.com")
          expect(cpp.html).to match_html <<~HTML
            <p>This post has a custom emoji <img src="#{upload_url}?v=#{Emoji::EMOJI_VERSION}" title=":trout:" class="emoji emoji-custom" alt=":trout:" loading="lazy" width="20" height="20"></p>
          HTML
        end

        context "with media uploads" do
          fab!(:image_upload) { Fabricate(:upload) }
          fab!(:audio_upload) { Fabricate(:upload, extension: "ogg") }
          fab!(:video_upload) { Fabricate(:upload, extension: "mov") }

          before do
            video_upload.update!(
              url: "#{SiteSetting.s3_cdn_url}/#{Discourse.store.get_path_for_upload(video_upload)}",
            )
            stub_request(:head, video_upload.url)
          end

          it "ignores prevent_anons_from_downloading_files and oneboxes video uploads" do
            SiteSetting.prevent_anons_from_downloading_files = true

            the_post =
              Fabricate(
                :post,
                user: user_with_auto_groups,
                raw: "This post has an S3 video onebox:\n#{video_upload.url}",
              )

            cpp = CookedPostProcessor.new(the_post.reload)
            cpp.post_process_oneboxes

            expect(cpp.html).to match_html <<~HTML
              <p>This post has an S3 video onebox:</p>
              <div class="onebox video-onebox">
                <video width="100%" height="100%" controls="">
                  <source src="#{video_upload.url}">
                  <a href="#{video_upload.url}" rel="nofollow ugc noopener">#{video_upload.url}</a>
                </video>
              </div>
            HTML
          end

          it "oneboxes video using secure url when secure_uploads is enabled" do
            SiteSetting.login_required = true
            SiteSetting.secure_uploads = true
            video_upload.update_column(:secure, true)

            the_post =
              Fabricate(
                :post,
                user: user_with_auto_groups,
                raw: "This post has an S3 video onebox:\n#{video_upload.url}",
              )

            cpp = CookedPostProcessor.new(the_post)
            cpp.post_process_oneboxes

            secure_url =
              video_upload.url.sub(SiteSetting.s3_cdn_url, "#{Discourse.base_url}/secure-uploads")

            expect(cpp.html).to match_html <<~HTML
              <p>This post has an S3 video onebox:</p><div class="onebox video-onebox">
                <video width="100%" height="100%" controls="">
                  <source src="#{secure_url}">
                  <a href="#{secure_url}">#{secure_url}</a>
                </video>
              </div>
            HTML
          end

          it "oneboxes only audio/video and not images when secure_uploads is enabled" do
            SiteSetting.login_required = true
            SiteSetting.secure_uploads = true

            video_upload.update_column(:secure, true)

            audio_upload.update!(
              url: "#{SiteSetting.s3_cdn_url}/#{Discourse.store.get_path_for_upload(audio_upload)}",
              secure: true,
            )

            image_upload.update!(
              url: "#{SiteSetting.s3_cdn_url}/#{Discourse.store.get_path_for_upload(image_upload)}",
              secure: true,
            )

            stub_request(:head, audio_upload.url)
            stub_request(:get, image_upload.url)

            raw = <<~RAW.rstrip
              This post has a video upload.
              #{video_upload.url}

              This post has an audio upload.
              #{audio_upload.url}

              And an image upload.
              ![logo.png](upload://#{image_upload.base62_sha1}.#{image_upload.extension})
            RAW

            the_post = Fabricate(:post, user: user_with_auto_groups, raw: raw)

            cpp = CookedPostProcessor.new(the_post)
            cpp.post_process_oneboxes

            secure_video_url =
              video_upload.url.sub(SiteSetting.s3_cdn_url, "#{Discourse.base_url}/secure-uploads")
            secure_audio_url =
              audio_upload.url.sub(SiteSetting.s3_cdn_url, "#{Discourse.base_url}/secure-uploads")

            expect(cpp.html).to match_html <<~HTML
              <p>This post has a video upload.</p><div class="onebox video-onebox">
                <video width="100%" height="100%" controls="">
                  <source src="#{secure_video_url}">
                  <a href="#{secure_video_url}">
                    #{secure_video_url}
                  </a>
                </video>
              </div>

              <p>This post has an audio upload.<br>
              <audio controls="">
                <source src="#{secure_audio_url}">
                <a href="#{secure_audio_url}">
                  #{secure_audio_url}
                </a>
              </audio>
              </p>
              <p>And an image upload.<br>
              <img src="#{image_upload.url}" alt="#{image_upload.original_filename}" data-base62-sha1="#{image_upload.base62_sha1}"></p>
            HTML
          end
        end
      end
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

      it "should not be marked as modified" do
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

      it "should be marked as modified" do
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

      it "it should be marked as missing" do
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

    it "works" do
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
end
