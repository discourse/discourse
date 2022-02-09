# frozen_string_literal: true

require "rails_helper"
require "cooked_post_processor"
require "file_store/s3_store"

describe CookedPostProcessor do
  fab!(:upload) { Fabricate(:upload) }
  let(:upload_path) { Discourse.store.upload_path }

  context "#post_process" do
    fab!(:post) do
      Fabricate(:post, raw: <<~RAW)
      <img src="#{upload.url}">
      RAW
    end

    let(:cpp) { CookedPostProcessor.new(post, disable_loading_image: true) }
    let(:post_process) { sequence("post_process") }

    it "post process in sequence" do
      cpp.expects(:post_process_oneboxes).in_sequence(post_process)
      cpp.expects(:post_process_images).in_sequence(post_process)
      cpp.expects(:optimize_urls).in_sequence(post_process)
      cpp.expects(:pull_hotlinked_images).in_sequence(post_process)
      cpp.post_process

      expect(PostUpload.exists?(post: post, upload: upload)).to eq(true)
    end

    describe 'when post contains oneboxes and inline oneboxes' do
      let(:url_hostname) { 'meta.discourse.org' }

      let(:url) do
        "https://#{url_hostname}/t/mini-inline-onebox-support-rfc/66400"
      end

      let(:not_oneboxed_url) do
        "https://#{url_hostname}/t/random-url"
      end

      let(:title) { 'some title' }

      let(:post) do
        Fabricate(:post, raw: <<~RAW)
        #{url}
        This is a #{url} with path

        #{not_oneboxed_url}

        This is a https://#{url_hostname}/t/another-random-url test
        This is a #{url} with path

        #{url}
        RAW
      end

      before do
        SiteSetting.enable_inline_onebox_on_all_domains = true

        %i{head get}.each do |method|
          stub_request(method, url).to_return(
            status: 200,
            body: <<~RAW
            <html>
              <head>
                <title>#{title}</title>
                <meta property='og:title' content="#{title}">
                <meta property='og:description' content="some description">
              </head>
            </html>
            RAW
          )
        end
      end

      after do
        InlineOneboxer.invalidate(url)
        Oneboxer.invalidate(url)
      end

      it 'should respect SiteSetting.max_oneboxes_per_post' do
        SiteSetting.max_oneboxes_per_post = 2
        SiteSetting.add_rel_nofollow_to_user_content = false

        cpp.post_process

        expect(cpp.html).to have_tag('a',
          with: { href: url, class: "inline-onebox" },
          text: title,
          count: 2
        )

        expect(cpp.html).to have_tag('aside.onebox a', text: title, count: 2)

        expect(cpp.html).to have_tag('aside.onebox a',
          text: url_hostname,
          count: 2
        )

        expect(cpp.html).to have_tag('a',
          without: { class: "inline-onebox-loading" },
          text: not_oneboxed_url,
          count: 1
        )

        expect(cpp.html).to have_tag('a',
          without: {
            class: 'onebox'
          },
          text: not_oneboxed_url,
          count: 1
        )
      end
    end

    describe 'when post contains inline oneboxes' do
      before do
        SiteSetting.enable_inline_onebox_on_all_domains = true
      end

      describe 'internal links' do
        fab!(:topic) { Fabricate(:topic) }
        fab!(:post) { Fabricate(:post, raw: "Hello #{topic.url}") }
        let(:url) { topic.url }

        it "includes the topic title" do
          cpp.post_process

          expect(cpp.html).to have_tag('a',
            with: { href: UrlHelper.cook_url(url) },
            without: { class: "inline-onebox-loading" },
            text: topic.title,
            count: 1
          )

          topic.update!(title: "Updated to something else")
          cpp = CookedPostProcessor.new(post, invalidate_oneboxes: true)
          cpp.post_process

          expect(cpp.html).to have_tag('a',
            with: { href: UrlHelper.cook_url(url) },
            without: { class: "inline-onebox-loading" },
            text: topic.title,
            count: 1
          )
        end
      end

      describe 'external links' do
        let(:url_with_path) do
          'https://meta.discourse.org/t/mini-inline-onebox-support-rfc/66400'
        end

        let(:url_with_query_param) do
          'https://meta.discourse.org?a'
        end

        let(:url_no_path) do
          'https://meta.discourse.org/'
        end

        let(:urls) do
          [
            url_with_path,
            url_with_query_param,
            url_no_path
          ]
        end

        let(:title) { '<b>some title</b>' }
        let(:escaped_title) { CGI.escapeHTML(title) }

        let(:post) do
          Fabricate(:post, raw: <<~RAW)
          This is a #{url_with_path} topic
          This should not be inline #{url_no_path} oneboxed

          - #{url_with_path}


             - #{url_with_query_param}
          RAW
        end

        let(:staff_post) do
          Fabricate(:post, user: Fabricate(:admin), raw: <<~RAW)
          This is a #{url_with_path} topic
          RAW
        end

        before do
          urls.each do |url|
            stub_request(:get, url).to_return(
              status: 200,
              body: "<html><head><title>#{escaped_title}</title></head></html>"
            )
          end
        end

        after do
          urls.each { |url| InlineOneboxer.invalidate(url) }
        end

        it 'should convert the right links to inline oneboxes' do
          cpp.post_process
          html = cpp.html

          expect(html).to_not have_tag('a',
            with: { href: url_no_path },
            without: { class: "inline-onebox-loading" },
            text: title
          )

          expect(html).to have_tag('a',
            with: { href: url_with_path },
            without: { class: "inline-onebox-loading" },
            text: title,
            count: 2
          )

          expect(html).to have_tag('a',
            with: { href: url_with_query_param },
            without: { class: "inline-onebox-loading" },
            text: title,
            count: 1
          )

          expect(html).to have_tag("a[rel='noopener nofollow ugc']")
        end

        it 'removes nofollow if user is staff/tl3' do
          cpp = CookedPostProcessor.new(staff_post, invalidate_oneboxes: true)
          cpp.post_process
          expect(cpp.html).to_not have_tag("a[rel='noopener nofollow ugc']")
        end
      end
    end

    context "processing images" do
      before do
        SiteSetting.responsive_post_image_sizes = ""
      end

      context "responsive images" do
        before { SiteSetting.responsive_post_image_sizes = "1|1.5|3" }

        it "includes responsive images on demand" do
          upload.update!(width: 2000, height: 1500, filesize: 10000)
          post = Fabricate(:post, raw: "hello <img src='#{upload.url}'>")

          # fake some optimized images
          OptimizedImage.create!(
            url: "/#{upload_path}/666x500.jpg",
            width: 666,
            height: 500,
            upload_id: upload.id,
            sha1: SecureRandom.hex,
            extension: '.jpg',
            filesize: 500,
            version: OptimizedImage::VERSION
          )

          # fake 3x optimized image, we lose 2 pixels here over original due to rounding on downsize
          OptimizedImage.create!(
            url: "/#{upload_path}/1998x1500.jpg",
            width: 1998,
            height: 1500,
            upload_id: upload.id,
            sha1: SecureRandom.hex,
            extension: '.jpg',
            filesize: 800
          )

          # Fake a loading image
          _optimized_image = OptimizedImage.create!(
            url: "/#{upload_path}/10x10.png",
            width: CookedPostProcessor::LOADING_SIZE,
            height: CookedPostProcessor::LOADING_SIZE,
            upload_id: upload.id,
            sha1: SecureRandom.hex,
            extension: '.png',
            filesize: 123
          )

          cpp = CookedPostProcessor.new(post)

          cpp.add_to_size_cache(upload.url, 2000, 1500)
          cpp.post_process

          html = cpp.html

          expect(html).to include(%Q|data-small-upload="//test.localhost/#{upload_path}/10x10.png"|)
          # 1.5x is skipped cause we have a missing thumb
          expect(html).to include("srcset=\"//test.localhost/#{upload_path}/666x500.jpg, //test.localhost/#{upload_path}/1998x1500.jpg 3x\"")
          expect(html).to include("src=\"//test.localhost/#{upload_path}/666x500.jpg\"")

          # works with CDN
          set_cdn_url("http://cdn.localhost")

          cpp = CookedPostProcessor.new(post)
          cpp.add_to_size_cache(upload.url, 2000, 1500)
          cpp.post_process

          html = cpp.html

          expect(html).to include(%Q|data-small-upload="//cdn.localhost/#{upload_path}/10x10.png"|)
          expect(html).to include("srcset=\"//cdn.localhost/#{upload_path}/666x500.jpg, //cdn.localhost/#{upload_path}/1998x1500.jpg 3x\"")
          expect(html).to include("src=\"//cdn.localhost/#{upload_path}/666x500.jpg\"")
        end

        it "doesn't include response images for cropped images" do
          upload.update!(width: 200, height: 4000, filesize: 12345)
          post = Fabricate(:post, raw: "hello <img src='#{upload.url}'>")

          # fake some optimized images
          OptimizedImage.create!(
            url: 'http://a.b.c/200x500.jpg',
            width: 200,
            height: 500,
            upload_id: upload.id,
            sha1: SecureRandom.hex,
            extension: '.jpg',
            filesize: 500
          )

          cpp = CookedPostProcessor.new(post)
          cpp.add_to_size_cache(upload.url, 200, 4000)
          cpp.post_process

          expect(cpp.html).to_not include('srcset="')
        end
      end

      shared_examples "leave dimensions alone" do
        it "doesn't use them" do
          expect(cpp.html).to match(/src="http:\/\/foo.bar\/image.png" width="" height=""/)
          expect(cpp.html).to match(/src="http:\/\/domain.com\/picture.jpg" width="50" height="42"/)
          expect(cpp).to be_dirty
        end
      end

      context "with image_sizes" do
        fab!(:post) { Fabricate(:post_with_image_urls) }
        let(:cpp) { CookedPostProcessor.new(post, image_sizes: image_sizes) }

        before do
          stub_image_size
          cpp.post_process
        end

        context "valid" do
          let(:image_sizes) { { "http://foo.bar/image.png" => { "width" => 111, "height" => 222 } } }

          it "uses them" do
            expect(cpp.html).to match(/src="http:\/\/foo.bar\/image.png" width="111" height="222"/)
            expect(cpp.html).to match(/src="http:\/\/domain.com\/picture.jpg" width="50" height="42"/)
            expect(cpp).to be_dirty
          end
        end

        context "invalid width" do
          let(:image_sizes) { { "http://foo.bar/image.png" => { "width" => 0, "height" => 222 } } }
          include_examples "leave dimensions alone"
        end

        context "invalid height" do
          let(:image_sizes) { { "http://foo.bar/image.png" => { "width" => 111, "height" => 0 } } }
          include_examples "leave dimensions alone"
        end

        context "invalid width & height" do
          let(:image_sizes) { { "http://foo.bar/image.png" => { "width" => 0, "height" => 0 } } }
          include_examples "leave dimensions alone"
        end

      end

      context "with unsized images" do
        fab!(:upload) { Fabricate(:image_upload, width: 123, height: 456) }

        fab!(:post) do
          Fabricate(:post, raw: <<~HTML)
          <img src="#{upload.url}">
          HTML
        end

        let(:cpp) { CookedPostProcessor.new(post) }

        it "adds the width and height to images that don't have them" do
          cpp.post_process
          expect(cpp.html).to match(/width="123" height="456"/)
          expect(cpp).to be_dirty
        end

      end

      context "with large images" do
        fab!(:upload) { Fabricate(:image_upload, width: 1750, height: 2000) }

        fab!(:post) do
          Fabricate(:post, raw: <<~HTML)
          <img src="#{upload.url}">
          HTML
        end

        let(:cpp) { CookedPostProcessor.new(post, disable_loading_image: true) }

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

        describe 'when image is inside onebox' do
          let(:url) { 'https://image.com/my-avatar' }
          let(:post) { Fabricate(:post, raw: url) }

          before do
            Oneboxer.stubs(:onebox).with(url, anything).returns("<img class='onebox' src='/#{upload_path}/original/1X/1234567890123456.jpg' />")
          end

          it 'should not add lightbox' do
            FastImage.expects(:size).returns([1750, 2000])

            cpp.post_process

            expect(cpp.html).to match_html <<~HTML
              <p><img class="onebox" src="//test.localhost/#{upload_path}/original/1X/1234567890123456.jpg" width="690" height="788"></p>
            HTML
          end
        end

        describe 'when image is an svg' do
          fab!(:post) do
            Fabricate(:post, raw: "<img src=\"/#{Discourse.store.upload_path}/original/1X/1234567890123456.svg\">")
          end

          it 'should not add lightbox' do
            FastImage.expects(:size).returns([1750, 2000])

            cpp.post_process

            expect(cpp.html).to match_html <<~HTML
              <p><img src="//test.localhost/#{upload_path}/original/1X/1234567890123456.svg" width="690" height="788"></p>
            HTML
          end

          describe 'when image src is an URL' do
            let(:post) do
              Fabricate(:post, raw: "<img src=\"http://test.discourse/#{upload_path}/original/1X/1234567890123456.svg?somepamas\">")
            end

            it 'should not add lightbox' do
              FastImage.expects(:size).returns([1750, 2000])

              cpp.post_process

              expect(cpp.html).to match_html("<p><img src=\"http://test.discourse/#{upload_path}/original/1X/1234567890123456.svg?somepamas\" width=\"690\"\ height=\"788\"></p>")
            end
          end
        end

        context "s3_uploads" do
          let(:upload) { Fabricate(:secure_upload_s3) }

          before do
            setup_s3
            SiteSetting.s3_cdn_url = "https://s3.cdn.com"
            SiteSetting.authorized_extensions = "png|jpg|gif|mov|ogg|"

            stored_path = Discourse.store.get_path_for_upload(upload)
            upload.update_column(:url, "#{SiteSetting.Upload.absolute_base_url}/#{stored_path}")

            stub_upload(upload)

            SiteSetting.login_required = true
            SiteSetting.secure_media = true
          end

          let(:optimized_size) { "600x500" }

          let(:post) do
            Fabricate(:post, raw: "![large.png|#{optimized_size}](#{upload.short_url})")
          end

          let(:cooked_html) do
            <<~HTML
            <p><div class="lightbox-wrapper"><a class="lightbox" href="//test.localhost/secure-media-uploads/original/1X/#{upload.sha1}.png" data-download-href="//test.localhost/uploads/short-url/#{upload.base62_sha1}.unknown?dl=1" title="large.png"><img src="" alt="large.png" data-base62-sha1="#{upload.base62_sha1}" width="600" height="500"><div class="meta">
            <svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">large.png</span><span class="informations">1750×2000 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg>
            </div></a></div></p>
            HTML
          end

          context "when the upload is attached to the correct post" do
            before do
              FastImage.expects(:size).returns([1750, 2000])
              OptimizedImage.expects(:resize).returns(true)
              Discourse.store.class.any_instance.expects(:has_been_uploaded?).at_least_once.returns(true)
              upload.update(secure: true, access_control_post: post)
            end

            # TODO fix this spec, it is sometimes getting CDN links when it runs concurrently
            xit "handles secure images with the correct lightbox link href" do
              cpp.post_process

              expect(cpp.html).to match_html cooked_html
            end
          end

          context "when the upload is attached to a different post" do
            before do
              FastImage.size(upload.url)
              upload.update(secure: true, access_control_post: Fabricate(:post))
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

        fab!(:post) do
          Fabricate(:post, raw: <<~HTML)
          <img src="#{upload.url}">
          HTML
        end

        let(:cpp) { CookedPostProcessor.new(post, disable_loading_image: true) }

        before do
          SiteSetting.create_thumbnails = true
        end

        it "resizes the image instead of crop" do
          cpp.post_process

          expect(cpp.html).to match(/width="113" height="500">/)
          expect(cpp).to be_dirty
        end

      end

      context "with taller images < default aspect ratio" do
        fab!(:upload) { Fabricate(:image_upload, width: 500, height: 2300) }

        fab!(:post) do
          Fabricate(:post, raw: <<~HTML)
          <img src="#{upload.url}">
          HTML
        end

        let(:cpp) { CookedPostProcessor.new(post, disable_loading_image: true) }

        before do
          SiteSetting.create_thumbnails = true
        end

        it "crops the image" do
          cpp.post_process

          expect(cpp.html).to match(/width="500" height="500">/)
          expect(cpp).to be_dirty
        end

      end

      context "with iPhone X screenshots" do
        fab!(:upload) { Fabricate(:image_upload, width: 1125, height: 2436) }

        fab!(:post) do
          Fabricate(:post, raw: <<~HTML)
          <img src="#{upload.url}">
          HTML
        end

        let(:cpp) { CookedPostProcessor.new(post, disable_loading_image: true) }

        before do
          SiteSetting.create_thumbnails = true
        end

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

        fab!(:post) do
          Fabricate(:post, raw: <<~HTML)
          <img src="/subfolder#{upload.url}">
          HTML
        end

        let(:cpp) { CookedPostProcessor.new(post, disable_loading_image: true) }

        before do
          set_subfolder "/subfolder"
          stub_request(:get, "http://#{Discourse.current_hostname}/subfolder#{upload.url}").to_return(status: 200, body: File.new(Discourse.store.path_for(upload)))

          SiteSetting.max_image_height = 2000
          SiteSetting.create_thumbnails = true
        end

        it "generates overlay information" do
          cpp.post_process

          expect(cpp.html). to match_html <<~HTML
            <p><div class="lightbox-wrapper"><a class="lightbox" href="//test.localhost/subfolder#{upload.url}" data-download-href="//test.localhost/subfolder/#{upload_path}/#{upload.sha1}" title="logo.png"><img src="//test.localhost/subfolder/#{upload_path}/optimized/1X/#{upload.sha1}_#{OptimizedImage::VERSION}_690x788.png" width="690" height="788"><div class="meta"><svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">logo.png</span><span class="informations">1750×2000 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg></div></a></div></p>
          HTML

          expect(cpp).to be_dirty
        end

        it "should escape the filename" do
          upload.update!(original_filename: "><img src=x onerror=alert('haha')>.png")
          cpp.post_process

          expect(cpp.html).to match_html <<~HTML
            <p><div class="lightbox-wrapper"><a class="lightbox" href="//test.localhost/subfolder#{upload.url}" data-download-href="//test.localhost/subfolder/#{upload_path}/#{upload.sha1}" title="&amp;gt;&amp;lt;img src=x onerror=alert(&amp;#39;haha&amp;#39;)&amp;gt;.png"><img src="//test.localhost/subfolder/#{upload_path}/optimized/1X/#{upload.sha1}_#{OptimizedImage::VERSION}_690x788.png" width="690" height="788"><div class="meta"><svg class="fa d-icon d-icon-far-image svg-icon" aria-hidden="true"><use href="#far-image"></use></svg><span class="filename">&amp;gt;&amp;lt;img src=x onerror=alert(&amp;#39;haha&amp;#39;)&amp;gt;.png</span><span class="informations">1750×2000 1.21 KB</span><svg class="fa d-icon d-icon-discourse-expand svg-icon" aria-hidden="true"><use href="#discourse-expand"></use></svg></div></a></div></p>
          HTML
        end

      end

      context "with title and alt" do
        fab!(:upload) { Fabricate(:image_upload, width: 1750, height: 2000) }

        fab!(:post) do
          Fabricate(:post, raw: <<~HTML)
          <img src="#{upload.url}" title="WAT" alt="RED">
          HTML
        end

        let(:cpp) { CookedPostProcessor.new(post, disable_loading_image: true) }

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

        fab!(:post) do
          Fabricate(:post, raw: <<~HTML)
          <img src="#{upload.url}" title="WAT">
          HTML
        end

        let(:cpp) { CookedPostProcessor.new(post, disable_loading_image: true) }

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

        fab!(:post) do
          Fabricate(:post, raw: <<~HTML)
          <img src="#{upload.url}" alt="RED">
          HTML
        end

        let(:cpp) { CookedPostProcessor.new(post, disable_loading_image: true) }

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

      context "topic image" do
        fab!(:post) { Fabricate(:post_with_uploaded_image) }
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

        it "won't remove the original image if another post doesn't have an image" do
          FastImage.stubs(:size)
          topic = post.topic

          cpp.post_process
          topic.reload
          expect(topic.image_upload_id).to be_present
          expect(post.image_upload_id).to be_present

          post = Fabricate(:post, topic: topic, raw: "this post doesn't have an image")
          CookedPostProcessor.new(post).post_process
          topic.reload

          expect(post.topic.image_upload_id).to be_present
          expect(post.image_upload_id).to be_blank
        end

        it "generates thumbnails correctly" do
          FastImage.expects(:size).returns([1750, 2000])

          topic = post.topic
          cpp.post_process
          topic.reload
          expect(topic.image_upload_id).to be_present
          expect(post.image_upload_id).to be_present

          post = Fabricate(:post, topic: topic, raw: "this post doesn't have an image")
          CookedPostProcessor.new(post).post_process
          topic.reload

          expect(post.topic.image_upload_id).to be_present
          expect(post.image_upload_id).to be_blank
        end
      end

      it "prioritizes data-thumbnail images" do
        upload1 = Fabricate(:image_upload, width: 1750, height: 2000)
        upload2 = Fabricate(:image_upload, width: 1750, height: 2000)
        post = Fabricate(:post, raw: <<~MD)
          ![alttext|1750x2000](#{upload1.url})
          ![alttext|1750x2000|thumbnail](#{upload2.url})
        MD

        CookedPostProcessor.new(post, disable_loading_image: true).post_process

        expect(post.reload.image_upload_id).to eq(upload2.id)
      end

      context "post image" do
        let(:reply) { Fabricate(:post_with_uploaded_image, post_number: 2) }
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

  context "#extract_images" do

    let(:post) { build(:post_with_plenty_of_images) }
    let(:cpp) { CookedPostProcessor.new(post) }

    it "does not extract emojis or images inside oneboxes or quotes" do
      expect(cpp.extract_images.length).to eq(0)
    end

  end

  context "#get_size_from_attributes" do

    let(:post) { build(:post) }
    let(:cpp) { CookedPostProcessor.new(post) }

    it "returns the size when width and height are specified" do
      img = { 'src' => 'http://foo.bar/image3.png', 'width' => 50, 'height' => 70 }
      expect(cpp.get_size_from_attributes(img)).to eq([50, 70])
    end

    it "returns the size when width and height are floats" do
      img = { 'src' => 'http://foo.bar/image3.png', 'width' => 50.2, 'height' => 70.1 }
      expect(cpp.get_size_from_attributes(img)).to eq([50, 70])
    end

    it "resizes when only width is specified" do
      img = { 'src' => 'http://foo.bar/image3.png', 'width' => 100 }
      FastImage.expects(:size).returns([200, 400])
      expect(cpp.get_size_from_attributes(img)).to eq([100, 200])
    end

    it "resizes when only height is specified" do
      img = { 'src' => 'http://foo.bar/image3.png', 'height' => 100 }
      FastImage.expects(:size).returns([100, 300])
      expect(cpp.get_size_from_attributes(img)).to eq([33, 100])
    end

    it "doesn't raise an error with a weird url" do
      img = { 'src' => nil, 'height' => 100 }
      expect(cpp.get_size_from_attributes(img)).to be_nil
    end

  end

  context "#get_size_from_image_sizes" do

    let(:post) { build(:post) }
    let(:cpp) { CookedPostProcessor.new(post) }

    it "returns the size" do
      image_sizes = { "http://my.discourse.org/image.png" => { "width" => 111, "height" => 222 } }
      expect(cpp.get_size_from_image_sizes("/image.png", image_sizes)).to eq([111, 222])
    end

  end

  context "#get_size" do

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

  context "#is_valid_image_url?" do

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

  context "#get_filename" do

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
      expect(cpp.get_filename(upload, "http://domain.com/image.png")).to eq(I18n.t('upload.pasted_image_filename'))
    end

  end

  context "#convert_to_link" do
    fab!(:thumbnail) { Fabricate(:optimized_image, upload: upload, width: 512, height: 384) }

    before do
      CookedPostProcessor.any_instance.stubs(:get_size).with(upload.url).returns([1024, 768])
    end

    it "adds lightbox and optimizes images" do
      post = Fabricate(:post, raw: "![image|1024x768, 50%](#{upload.short_url})")

      cpp = CookedPostProcessor.new(post, disable_loading_image: true)
      cpp.post_process

      doc = Nokogiri::HTML5::fragment(cpp.html)
      expect(doc.css('.lightbox-wrapper').size).to eq(1)
      expect(doc.css('img').first['srcset']).to_not eq(nil)
    end

    it "processes animated images correctly" do
      # skips optimization
      # skips lightboxing
      # adds "animated" class to element
      upload.update!(animated: true)
      post = Fabricate(:post, raw: "![image|1024x768, 50%](#{upload.short_url})")

      cpp = CookedPostProcessor.new(post, disable_loading_image: true)
      cpp.post_process

      doc = Nokogiri::HTML5::fragment(cpp.html)
      expect(doc.css('.lightbox-wrapper').size).to eq(0)
      expect(doc.css('img').first['src']).to include(upload.url)
      expect(doc.css('img').first['srcset']).to eq(nil)
      expect(doc.css('img.animated').size).to eq(1)
    end

    context "giphy/tenor images" do
      before do
        CookedPostProcessor.any_instance.stubs(:get_size).with("https://media2.giphy.com/media/7Oifk90VrCdNe/giphy.webp").returns([311, 280])
        CookedPostProcessor.any_instance.stubs(:get_size).with("https://media1.tenor.com/images/20c7ddd5e84c7427954f430439c5209d/tenor.gif").returns([833, 104])
      end

      it "marks giphy images as animated" do
        post = Fabricate(:post, raw: "![tennis-gif|311x280](https://media2.giphy.com/media/7Oifk90VrCdNe/giphy.webp)")
        cpp = CookedPostProcessor.new(post, disable_loading_image: true)
        cpp.post_process

        doc = Nokogiri::HTML5::fragment(cpp.html)
        expect(doc.css('img.animated').size).to eq(1)
      end

      it "marks giphy images as animated" do
        post = Fabricate(:post, raw: "![cat](https://media1.tenor.com/images/20c7ddd5e84c7427954f430439c5209d/tenor.gif)")
        cpp = CookedPostProcessor.new(post, disable_loading_image: true)
        cpp.post_process

        doc = Nokogiri::HTML5::fragment(cpp.html)
        expect(doc.css('img.animated').size).to eq(1)
      end
    end

    it "optimizes images in quotes" do
      post = Fabricate(:post, raw: <<~MD)
        [quote]
        ![image|1024x768, 50%](#{upload.short_url})
        [/quote]
      MD

      cpp = CookedPostProcessor.new(post, disable_loading_image: true)
      cpp.post_process

      doc = Nokogiri::HTML5::fragment(cpp.html)
      expect(doc.css('.lightbox-wrapper').size).to eq(0)
      expect(doc.css('img').first['srcset']).to_not eq(nil)
    end

    it "optimizes images in Onebox" do
      Oneboxer.expects(:onebox)
        .with("https://discourse.org", anything)
        .returns("<aside class='onebox'><img src='#{upload.url}' width='512' height='384'></aside>")

      post = Fabricate(:post, raw: "https://discourse.org")

      cpp = CookedPostProcessor.new(post, disable_loading_image: true)
      cpp.post_process

      doc = Nokogiri::HTML5::fragment(cpp.html)
      expect(doc.css('.lightbox-wrapper').size).to eq(0)
      expect(doc.css('img').first['srcset']).to_not eq(nil)
    end
  end

  context "#post_process_oneboxes" do
    let(:post) { build(:post_with_youtube, id: 123) }
    let(:cpp) { CookedPostProcessor.new(post, invalidate_oneboxes: true) }

    before do
      Oneboxer
        .expects(:onebox)
        .with("http://www.youtube.com/watch?v=9bZkp7q19f0", invalidate_oneboxes: true, user_id: nil, category_id: post.topic.category_id)
        .returns("<div>GANGNAM STYLE</div>")

      cpp.post_process_oneboxes
    end

    it "inserts the onebox without wrapping p" do
      expect(cpp).to be_dirty
      expect(cpp.html).to match_html "<div>GANGNAM STYLE</div>"
    end

    describe "replacing downloaded onebox image" do
      let(:url) { 'https://image.com/my-avatar' }
      let(:image_url) { 'https://image.com/avatar.png' }

      it "successfully replaces the image" do
        Oneboxer.stubs(:onebox).with(url, anything).returns("<img class='onebox' src='#{image_url}' />")

        post = Fabricate(:post, raw: url)
        upload.update!(url: "https://test.s3.amazonaws.com/something.png")

        post.custom_fields[Post::DOWNLOADED_IMAGES] = { "//image.com/avatar.png": upload.id }
        post.save_custom_fields

        cpp = CookedPostProcessor.new(post, invalidate_oneboxes: true)
        stub_image_size(width: 100, height: 200)
        cpp.post_process_oneboxes

        expect(cpp.doc.to_s).to eq("<p><img class=\"onebox\" src=\"#{upload.url}\" width=\"100\" height=\"200\"></p>")

        upload.destroy!
        cpp = CookedPostProcessor.new(post, invalidate_oneboxes: true)
        stub_image_size(width: 100, height: 200)
        cpp.post_process_oneboxes

        expect(cpp.doc.to_s).to eq("<p><img class=\"onebox\" src=\"#{image_url}\" width=\"100\" height=\"200\"></p>")
        Oneboxer.unstub(:onebox)
      end

      context "when the post is with_secure_media and the upload is secure and secure media is enabled" do
        before do
          setup_s3
          upload.update(secure: true)

          SiteSetting.login_required = true
          SiteSetting.secure_media = true
        end

        it "does not use the direct URL, uses the cooked URL instead (because of the private ACL preventing w/h fetch)" do
          Oneboxer.stubs(:onebox).with(url, anything).returns("<img class='onebox' src='#{image_url}' />")

          post = Fabricate(:post, raw: url)
          upload.update!(url: "https://test.s3.amazonaws.com/something.png")

          post.custom_fields[Post::DOWNLOADED_IMAGES] = { "//image.com/avatar.png": upload.id }
          post.save_custom_fields

          cooked_url = "https://localhost/secure-media-uploads/test.png"
          UrlHelper.expects(:cook_url).with(upload.url, secure: true).returns(cooked_url)

          cpp = CookedPostProcessor.new(post, invalidate_oneboxes: true)
          stub_image_size(width: 100, height: 200)
          cpp.post_process_oneboxes

          expect(cpp.doc.to_s).to eq("<p><img class=\"onebox\" src=\"#{cooked_url}\" width=\"100\" height=\"200\"></p>")
        end
      end
    end

    it "replaces large image placeholder" do
      SiteSetting.max_image_size_kb = 4096
      url = 'https://image.com/my-avatar'
      image_url = 'https://image.com/avatar.png'

      Oneboxer.stubs(:onebox).with(url, anything).returns("<img class='onebox' src='#{image_url}' />")

      post = Fabricate(:post, raw: url)

      post.custom_fields[Post::LARGE_IMAGES] = ["//image.com/avatar.png"]
      post.save_custom_fields

      cpp = CookedPostProcessor.new(post, invalidate_oneboxes: true)
      cpp.post_process

      expect(cpp.doc.to_s).to match(/<div class="large-image-placeholder">/)
      expect(cpp.doc.to_s).to include(I18n.t("upload.placeholders.too_large_humanized", max_size: "4 MB"))
    end
  end

  context "#post_process_oneboxes removes nofollow if add_rel_nofollow_to_user_content is disabled" do
    let(:post) { build(:post_with_youtube, id: 123) }
    let(:cpp) { CookedPostProcessor.new(post, invalidate_oneboxes: true) }

    before do
      SiteSetting.add_rel_nofollow_to_user_content = false
      Oneboxer.expects(:onebox)
        .with("http://www.youtube.com/watch?v=9bZkp7q19f0", invalidate_oneboxes: true, user_id: nil, category_id: post.topic.category_id)
        .returns('<aside class="onebox"><a href="https://www.youtube.com/watch?v=9bZkp7q19f0" rel="noopener nofollow ugc">GANGNAM STYLE</a></aside>')
      cpp.post_process_oneboxes
    end

    it "removes nofollow noopener from links" do
      expect(cpp).to be_dirty
      expect(cpp.html).to match_html '<aside class="onebox"><a href="https://www.youtube.com/watch?v=9bZkp7q19f0" rel="noopener">GANGNAM STYLE</a></aside>'
    end
  end

  context "#post_process_oneboxes removes nofollow if user is tl3" do
    let(:post) { build(:post_with_youtube, id: 123) }
    let(:cpp) { CookedPostProcessor.new(post, invalidate_oneboxes: true) }

    before do
      post.user.trust_level = TrustLevel[3]
      post.user.save!
      SiteSetting.add_rel_nofollow_to_user_content = true
      SiteSetting.tl3_links_no_follow = false
      Oneboxer.expects(:onebox)
        .with("http://www.youtube.com/watch?v=9bZkp7q19f0", invalidate_oneboxes: true, user_id: nil, category_id: post.topic.category_id)
        .returns('<aside class="onebox"><a href="https://www.youtube.com/watch?v=9bZkp7q19f0" rel="noopener nofollow ugc">GANGNAM STYLE</a></aside>')
      cpp.post_process_oneboxes
    end

    it "removes nofollow ugc from links" do
      expect(cpp).to be_dirty
      expect(cpp.html).to match_html '<aside class="onebox"><a href="https://www.youtube.com/watch?v=9bZkp7q19f0" rel="noopener">GANGNAM STYLE</a></aside>'
    end
  end

  context "#post_process_oneboxes with oneboxed image" do
    let(:post) { build(:post_with_youtube, id: 123) }
    let(:cpp) { CookedPostProcessor.new(post, invalidate_oneboxes: true) }

    it "applies aspect ratio to container" do
      Oneboxer.expects(:onebox)
        .with("http://www.youtube.com/watch?v=9bZkp7q19f0", invalidate_oneboxes: true, user_id: nil, category_id: post.topic.category_id)
        .returns("<aside class='onebox'><div class='scale-images'><img src='/img.jpg' width='400' height='500'/></div></div>")

      cpp.post_process_oneboxes

      expect(cpp.html).to match_html('<aside class="onebox"><div class="aspect-image-full-size" style="--aspect-ratio:400/500;"><img src="/img.jpg"></div></aside>')
    end

    it "applies aspect ratio when wrapped in link" do
      Oneboxer.expects(:onebox)
        .with("http://www.youtube.com/watch?v=9bZkp7q19f0", invalidate_oneboxes: true, user_id: nil, category_id: post.topic.category_id)
        .returns("<aside class='onebox'><div class='scale-images'><a href='https://example.com'><img src='/img.jpg' width='400' height='500'/></a></div></div>")

      cpp.post_process_oneboxes

      expect(cpp.html).to match_html('<aside class="onebox"><div class="aspect-image-full-size" style="--aspect-ratio:400/500;"><a href="https://example.com"><img src="/img.jpg"></a></div></aside>')
    end
  end

  context "#post_process_oneboxes with square image" do

    it "generates a onebox-avatar class" do
      url = 'https://square-image.com/onebox'

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
      stub_request(:get , url).to_return(body: body)
      FinalDestination.stubs(:lookup_ip).returns('1.2.3.4')

      # not an ideal stub but shipping the whole image to fast image can add
      # a lot of cost to this test
      stub_image_size(width: 200, height: 200)

      post = Fabricate.build(:post, raw: url)
      cpp = CookedPostProcessor.new(post, invalidate_oneboxes: true)

      cpp.post_process_oneboxes

      expect(cpp.doc.to_s).not_to include('aspect-image')
      expect(cpp.doc.to_s).to include('onebox-avatar')
    end

  end

  context "#optimize_urls" do

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

      context "s3_uploads" do
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

          the_post = Fabricate(:post, raw: %Q{This post has a local emoji :+1: and an external upload\n\n![smallest.png|10x20](#{upload.short_url})})

          cpp = CookedPostProcessor.new(the_post)
          cpp.optimize_urls

          expect(cpp.html).to match_html <<~HTML
            <p>This post has a local emoji <img src="https://local.cdn.com/images/emoji/twitter/+1.png?v=#{Emoji::EMOJI_VERSION}" title=":+1:" class="emoji" alt=":+1:" loading="lazy" width="20" height="20"> and an external upload</p>
            <p><img src="https://s3.cdn.com/#{stored_path}" alt="smallest.png" data-base62-sha1="#{upload.base62_sha1}" width="10" height="20"></p>
          HTML
        end

        it "doesn't use CDN for secure media" do
          SiteSetting.secure_media = true

          stored_path = Discourse.store.get_path_for_upload(upload)
          upload.update_column(:url, "#{SiteSetting.Upload.absolute_base_url}/#{stored_path}")
          upload.update_column(:secure, true)

          the_post = Fabricate(:post, raw: %Q{This post has a local emoji :+1: and an external upload\n\n![smallest.png|10x20](#{upload.short_url})})

          cpp = CookedPostProcessor.new(the_post)
          cpp.optimize_urls

          expect(cpp.html).to match_html <<~HTML
            <p>This post has a local emoji <img src="https://local.cdn.com/images/emoji/twitter/+1.png?v=#{Emoji::EMOJI_VERSION}" title=":+1:" class="emoji" alt=":+1:" loading="lazy" width="20" height="20"> and an external upload</p>
            <p><img src="/secure-media-uploads/#{stored_path}" alt="smallest.png" data-base62-sha1="#{upload.base62_sha1}" width="10" height="20"></p>
          HTML
        end

        context "media uploads" do
          fab!(:image_upload) { Fabricate(:upload) }
          fab!(:audio_upload) { Fabricate(:upload, extension: "ogg") }
          fab!(:video_upload) { Fabricate(:upload, extension: "mov") }

          before do
            video_upload.update!(url: "#{SiteSetting.s3_cdn_url}/#{Discourse.store.get_path_for_upload(video_upload)}")
            stub_request(:head, video_upload.url)
          end

          it "ignores prevent_anons_from_downloading_files and oneboxes video uploads" do
            SiteSetting.prevent_anons_from_downloading_files = true

            the_post = Fabricate(:post, raw: "This post has an S3 video onebox:\n#{video_upload.url}")

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

          it "oneboxes video using secure url when secure_media is enabled" do
            SiteSetting.login_required = true
            SiteSetting.secure_media = true
            video_upload.update_column(:secure, true)

            the_post = Fabricate(:post, raw: "This post has an S3 video onebox:\n#{video_upload.url}")

            cpp = CookedPostProcessor.new(the_post)
            cpp.post_process_oneboxes

            secure_url = video_upload.url.sub(SiteSetting.s3_cdn_url, "#{Discourse.base_url}/secure-media-uploads")

            expect(cpp.html).to match_html <<~HTML
              <p>This post has an S3 video onebox:</p><div class="onebox video-onebox">
                <video width="100%" height="100%" controls="">
                  <source src="#{secure_url}">
                  <a href="#{secure_url}">#{secure_url}</a>
                </video>
              </div>
            HTML
          end

          it "oneboxes only audio/video and not images when secure_media is enabled" do
            SiteSetting.login_required = true
            SiteSetting.secure_media = true

            video_upload.update_column(:secure, true)

            audio_upload.update!(
              url: "#{SiteSetting.s3_cdn_url}/#{Discourse.store.get_path_for_upload(audio_upload)}",
              secure: true
            )

            image_upload.update!(
              url: "#{SiteSetting.s3_cdn_url}/#{Discourse.store.get_path_for_upload(image_upload)}",
              secure: true
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

            the_post = Fabricate(:post, raw: raw)

            cpp = CookedPostProcessor.new(the_post)
            cpp.post_process_oneboxes

            secure_video_url = video_upload.url.sub(SiteSetting.s3_cdn_url, "#{Discourse.base_url}/secure-media-uploads")
            secure_audio_url = audio_upload.url.sub(SiteSetting.s3_cdn_url, "#{Discourse.base_url}/secure-media-uploads")

            expect(cpp.html).to match_html <<~HTML
              <p>This post has a video upload.</p>
              <div class="onebox video-onebox">
                <video width="100%" height="100%" controls="">
                  <source src="#{secure_video_url}">
                  <a href="#{secure_video_url}">#{secure_video_url}</a>
                </video>
              </div>
              <p>This post has an audio upload.<br>
              <audio controls=""><source src="#{secure_audio_url}"><a href="#{secure_audio_url}">#{secure_audio_url}</a></audio></p>
              <p>And an image upload.<br>
              <img src="#{image_upload.url}" alt="#{image_upload.original_filename}" data-base62-sha1="#{image_upload.base62_sha1}"></p>
            HTML
          end

        end
      end
    end

  end

  context "#remove_user_ids" do
    let(:topic) { Fabricate(:topic) }

    let(:post) do
      Fabricate(:post, raw: <<~RAW)
        link to a topic: #{topic.url}?u=foo

        a tricky link to a topic: #{topic.url}?bob=bob;u=sam&jane=jane

        link to an external topic: https://google.com/?u=bar

        a malformed url: https://www.example.com/#123#4
      RAW
    end

    let(:cpp) { CookedPostProcessor.new(post, disable_loading_image: true) }

    it "does remove user ids" do
      cpp.remove_user_ids

      expect(cpp.html).to have_tag('a', with: { href: topic.url })
      expect(cpp.html).to have_tag('a', with: { href: "#{topic.url}?bob=bob&jane=jane" })
      expect(cpp.html).to have_tag('a', with: { href: "https://google.com/?u=bar" })
      expect(cpp.html).to have_tag('a', with: { href: "https://www.example.com/#123#4" })
    end
  end

  context "#pull_hotlinked_images" do

    let(:post) { build(:post, created_at: 20.days.ago) }
    let(:cpp) { CookedPostProcessor.new(post) }

    before { cpp.stubs(:available_disk_space).returns(90) }

    it "runs even when download_remote_images_to_local is disabled" do
      # We want to run it to pull hotlinked optimized images
      SiteSetting.download_remote_images_to_local = false
      expect { cpp.pull_hotlinked_images }.
        to change { Jobs::PullHotlinkedImages.jobs.count }.by 1
    end

    context "when download_remote_images_to_local? is enabled" do
      before do
        SiteSetting.download_remote_images_to_local = true
      end

      it "disables download_remote_images if there is not enough disk space" do
        cpp.expects(:available_disk_space).returns(5)
        cpp.pull_hotlinked_images
        expect(SiteSetting.download_remote_images_to_local).to eq(false)
      end

      it "does not run when requested to skip" do
        CookedPostProcessor.new(post, skip_pull_hotlinked_images: true).pull_hotlinked_images
        expect(Jobs::PullHotlinkedImages.jobs.size).to eq(0)
      end

      context "and there is enough disk space" do
        before { cpp.expects(:disable_if_low_on_disk_space).at_least_once }

        context "and the post has been updated by an actual user" do

          before { post.id = 42 }

          it "ensures only one job is scheduled right after the editing_grace_period" do
            freeze_time

            Jobs.expects(:cancel_scheduled_job).with(:pull_hotlinked_images, post_id: post.id).once

            delay = SiteSetting.editing_grace_period + 1

            expect_enqueued_with(job: :pull_hotlinked_images, args: { post_id: post.id }, at: Time.zone.now + delay.seconds) do
              cpp.pull_hotlinked_images
            end
          end

        end

      end

    end

  end

  context "#disable_if_low_on_disk_space" do

    let(:post) { build(:post, created_at: 20.days.ago) }
    let(:cpp) { CookedPostProcessor.new(post) }

    before do
      SiteSetting.download_remote_images_to_local = true
      SiteSetting.download_remote_images_threshold = 20
      cpp.stubs(:available_disk_space).returns(50)
    end

    it "does nothing when there's enough disk space" do
      SiteSetting.expects(:download_remote_images_to_local=).never
      cpp.disable_if_low_on_disk_space
    end

    context "when there's not enough disk space" do

      before { SiteSetting.download_remote_images_threshold = 75 }

      it "disables download_remote_images_threshold and send a notification to the admin" do
        StaffActionLogger.any_instance.expects(:log_site_setting_change).once
        SystemMessage.expects(:create_from_system_user).with(Discourse.site_contact_user, :download_remote_images_disabled).once
        cpp.disable_if_low_on_disk_space

        expect(SiteSetting.download_remote_images_to_local).to eq(false)
      end

      it "doesn't disable download_remote_images_to_local if site uses S3" do
        setup_s3
        cpp.disable_if_low_on_disk_space

        expect(SiteSetting.download_remote_images_to_local).to eq(true)
      end

    end

  end

  context "#is_a_hyperlink?" do

    let(:post) { build(:post) }
    let(:cpp) { CookedPostProcessor.new(post) }
    let(:doc) { Nokogiri::HTML5::fragment('<body><div><a><img id="linked_image"></a><p><img id="standard_image"></p></div></body>') }

    it "is true when the image is inside a link" do
      img = doc.css("img#linked_image").first
      expect(cpp.is_a_hyperlink?(img)).to eq(true)
    end

    it "is false when the image is not inside a link" do
      img = doc.css("img#standard_image").first
      expect(cpp.is_a_hyperlink?(img)).to eq(false)
    end

  end

  context "grant badges" do
    let(:cpp) { CookedPostProcessor.new(post) }

    context "emoji inside a quote" do
      let(:post) { Fabricate(:post, raw: "time to eat some sweet \n[quote]\n:candy:\n[/quote]\n mmmm") }

      it "doesn't award a badge when the emoji is in a quote" do
        cpp.grant_badges
        expect(post.user.user_badges.where(badge_id: Badge::FirstEmoji).exists?).to eq(false)
      end
    end

    context "emoji in the text" do
      let(:post) { Fabricate(:post, raw: "time to eat some sweet :candy: mmmm") }

      it "awards a badge for using an emoji" do
        cpp.grant_badges
        expect(post.user.user_badges.where(badge_id: Badge::FirstEmoji).exists?).to eq(true)
      end
    end

    context "onebox" do
      before do
        Oneboxer.stubs(:onebox).with(anything, anything).returns(nil)
        Oneboxer.stubs(:onebox).with('https://discourse.org', anything).returns("<aside class=\"onebox allowlistedgeneric\">the rest of the onebox</aside>")
      end

      it "awards the badge for using an onebox" do
        post = Fabricate(:post, raw: "onebox me:\n\nhttps://discourse.org\n")
        cpp = CookedPostProcessor.new(post)
        cpp.post_process_oneboxes
        cpp.grant_badges
        expect(post.user.user_badges.where(badge_id: Badge::FirstOnebox).exists?).to eq(true)
      end

      it "does not award the badge when link is not oneboxed" do
        post = Fabricate(:post, raw: "onebox me:\n\nhttp://example.com\n")
        cpp = CookedPostProcessor.new(post)
        cpp.post_process_oneboxes
        cpp.grant_badges
        expect(post.user.user_badges.where(badge_id: Badge::FirstOnebox).exists?).to eq(false)
      end

      it "does not award the badge when the badge is disabled" do
        Badge.where(id: Badge::FirstOnebox).update_all(enabled: false)
        post = Fabricate(:post, raw: "onebox me:\n\nhttps://discourse.org\n")
        cpp = CookedPostProcessor.new(post)
        cpp.post_process_oneboxes
        cpp.grant_badges
        expect(post.user.user_badges.where(badge_id: Badge::FirstOnebox).exists?).to eq(false)
      end
    end

    context "reply_by_email" do
      let(:post) { Fabricate(:post, raw: "This is a **reply** via email ;)", via_email: true, post_number: 2) }

      it "awards a badge for replying via email" do
        cpp.grant_badges
        expect(post.user.user_badges.where(badge_id: Badge::FirstReplyByEmail).exists?).to eq(true)
      end
    end

  end

  context "quote processing" do
    let(:cpp) { CookedPostProcessor.new(cp) }
    let(:pp) { Fabricate(:post, raw: "This post is ripe for quoting!") }

    context "with an unmodified quote" do
      let(:cp) do
        Fabricate(
          :post,
          raw: "[quote=\"#{pp.user.username}, post: #{pp.post_number}, topic:#{pp.topic_id}]\nripe for quoting\n[/quote]\ntest"
        )
      end

      it "should not be marked as modified" do
        cpp.post_process_quotes
        expect(cpp.doc.css('aside.quote.quote-modified')).to be_blank
      end
    end

    context "with a modified quote" do
      let(:cp) do
        Fabricate(
          :post,
          raw: "[quote=\"#{pp.user.username}, post: #{pp.post_number}, topic:#{pp.topic_id}]\nmodified\n[/quote]\ntest"
        )
      end

      it "should be marked as modified" do
        cpp.post_process_quotes
        expect(cpp.doc.css('aside.quote.quote-modified')).to be_present
      end
    end

  end

  context "full quote on direct reply" do
    fab!(:topic) { Fabricate(:topic) }
    let!(:post) { Fabricate(:post, topic: topic, raw: 'this is the "first" post') }

    let(:raw) do
      <<~RAW.strip
      [quote="#{post.user.username}, post:#{post.post_number}, topic:#{topic.id}"]

      this is the “first” post

      [/quote]

      and this is the third reply
      RAW
    end

    let(:raw2) do
      <<~RAW.strip
      and this is the third reply

      [quote="#{post.user.username}, post:#{post.post_number}, topic:#{topic.id}"]
      this is the ”first” post
      [/quote]
      RAW
    end

    let(:raw3) do
      <<~RAW.strip
      [quote="#{post.user.username}, post:#{post.post_number}, topic:#{topic.id}"]

      this is the “first” post

      [/quote]

      [quote="#{post.user.username}, post:#{post.post_number}, topic:#{topic.id}"]

      this is the “first” post

      [/quote]

      and this is the third reply
      RAW
    end

    before do
      SiteSetting.remove_full_quote = true
    end

    it 'works' do
      hidden = Fabricate(:post, topic: topic, hidden: true, raw: "this is the second post after")
      small_action = Fabricate(:post, topic: topic, post_type: Post.types[:small_action])
      reply = Fabricate(:post, topic: topic, raw: raw)

      freeze_time do
        topic.bumped_at = 1.day.ago
        CookedPostProcessor.new(reply).remove_full_quote_on_direct_reply

        expect(topic.ordered_posts.pluck(:id))
          .to eq([post.id, hidden.id, small_action.id, reply.id])

        expect(topic.bumped_at).to eq_time(1.day.ago)
        expect(reply.raw).to eq("and this is the third reply")
        expect(reply.revisions.count).to eq(1)
        expect(reply.revisions.first.modifications["raw"]).to eq([raw, reply.raw])
        expect(reply.revisions.first.modifications["edit_reason"][1]).to eq(I18n.t(:removed_direct_reply_full_quotes))
      end
    end

    it 'does nothing if there are multiple quotes' do
      reply = Fabricate(:post, topic: topic, raw: raw3)
      CookedPostProcessor.new(reply).remove_full_quote_on_direct_reply
      expect(topic.ordered_posts.pluck(:id)).to eq([post.id, reply.id])
      expect(reply.raw).to eq(raw3)
    end

    it 'does not delete quote if not first paragraph' do
      reply = Fabricate(:post, topic: topic, raw: raw2)
      CookedPostProcessor.new(reply).remove_full_quote_on_direct_reply
      expect(topic.ordered_posts.pluck(:id)).to eq([post.id, reply.id])
      expect(reply.raw).to eq(raw2)
    end

    it "does nothing when 'remove_full_quote' is disabled" do
      SiteSetting.remove_full_quote = false

      reply = Fabricate(:post, topic: topic, raw: raw)

      CookedPostProcessor.new(reply).remove_full_quote_on_direct_reply
      expect(reply.raw).to eq(raw)
    end

    it "does not generate a blank HTML document" do
      post = Fabricate(:post, topic: topic, raw: "<sunday><monday>")
      cp = CookedPostProcessor.new(post)
      cp.post_process
      expect(cp.html).to eq("<p></p>")
    end

    it "works only on new posts" do
      Fabricate(:post, topic: topic, hidden: true, raw: "this is the second post after")
      Fabricate(:post, topic: topic, post_type: Post.types[:small_action])
      reply = PostCreator.create!(topic.user, topic_id: topic.id, raw: raw)

      stub_image_size
      CookedPostProcessor.new(reply).post_process
      expect(reply.raw).to eq(raw)

      PostRevisor.new(reply).revise!(Discourse.system_user, raw: raw, edit_reason: "put back full quote")

      stub_image_size
      CookedPostProcessor.new(reply).post_process(new_post: true)
      expect(reply.raw).to eq("and this is the third reply")
    end

    it "works with nested quotes" do
      reply1 = Fabricate(:post, topic: topic, raw: raw)
      reply2 = Fabricate(:post, topic: topic, raw: <<~RAW.strip)
        [quote="#{reply1.user.username}, post:#{reply1.post_number}, topic:#{topic.id}"]
        #{raw}
        [/quote]

        quoting a post with a quote
      RAW

      CookedPostProcessor.new(reply2).remove_full_quote_on_direct_reply
      expect(reply2.raw).to eq('quoting a post with a quote')
    end
  end

  context "#html" do
    it "escapes attributes" do
      post = Fabricate(:post, raw: '<img alt="<something>">')
      expect(post.cook(post.raw)).to eq('<p><img alt="&lt;something&gt;"></p>')
      expect(CookedPostProcessor.new(post).html).to eq('<p><img alt="&lt;something&gt;"></p>')
    end
  end

end
