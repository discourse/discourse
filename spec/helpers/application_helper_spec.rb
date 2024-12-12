# coding: utf-8
# frozen_string_literal: true

RSpec.describe ApplicationHelper do
  describe "preload_script" do
    def script_tag(url, entrypoint, nonce)
      <<~HTML
          <script defer src="#{url}" data-discourse-entrypoint="#{entrypoint}" nonce="#{nonce}"></script>
      HTML
    end

    it "does not send crawler content to logged on users" do
      controller.stubs(:use_crawler_layout?).returns(false)
      helper.stubs(:current_user).returns(Fabricate(:user))

      helper.request.user_agent = "Firefox"
      expect(helper.include_crawler_content?).to eq(false)
    end

    it "sends crawler content to logged on users who wants to print" do
      helper.stubs(:current_user).returns(Fabricate(:user))
      controller.stubs(:use_crawler_layout?).returns(false)
      helper.stubs(:params).returns(print: true)

      expect(helper.include_crawler_content?).to eq(true)
    end

    it "sends crawler content to logged on users with a crawler user agent" do
      helper.stubs(:current_user).returns(Fabricate(:user))
      controller.stubs(:use_crawler_layout?).returns(true)

      expect(helper.include_crawler_content?).to eq(true)
    end

    it "sends crawler content to old mobiles" do
      controller.stubs(:use_crawler_layout?).returns(false)

      helper.request.user_agent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 6_0 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10A5376e Safari/8536.25"

      expect(helper.include_crawler_content?).to eq(true)
    end

    it "does not send crawler content to new mobiles" do
      controller.stubs(:use_crawler_layout?).returns(false)

      helper.request.user_agent =
        "Mozilla/5.0 (Linux; Android 6.0.1; Nexus 5X Build/MMB29P) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.60 Mobile Safari/537.36 (compatible"

      expect(helper.include_crawler_content?).to eq(false)
    end

    context "with s3 CDN" do
      before do
        global_setting :s3_bucket, "test_bucket"
        global_setting :s3_region, "ap-australia"
        global_setting :s3_access_key_id, "123"
        global_setting :s3_secret_access_key, "123"
        global_setting :s3_cdn_url, "https://s3cdn.com"
      end

      it "deals correctly with subfolder" do
        set_subfolder "/community"
        expect(helper.preload_script("start-discourse")).to include(
          "https://s3cdn.com/assets/start-discourse.js",
        )
      end

      it "replaces cdn URLs with s3 cdn subfolder paths" do
        global_setting :s3_cdn_url, "https://s3cdn.com/s3_subpath"
        set_cdn_url "https://awesome.com"
        set_subfolder "/community"
        expect(helper.preload_script("start-discourse")).to include(
          "https://s3cdn.com/s3_subpath/assets/start-discourse.js",
        )
      end

      it "returns magic brotli mangling for brotli requests" do
        helper.request.env["HTTP_ACCEPT_ENCODING"] = "br"
        link = helper.preload_script("start-discourse")

        expect(link).to eq(
          script_tag(
            "https://s3cdn.com/assets/start-discourse.br.js",
            "start-discourse",
            helper.csp_nonce_placeholder,
          ),
        )
      end

      it "gives s3 cdn if asset host is not set" do
        link = helper.preload_script("start-discourse")

        expect(link).to eq(
          script_tag(
            "https://s3cdn.com/assets/start-discourse.js",
            "start-discourse",
            helper.csp_nonce_placeholder,
          ),
        )
      end

      it "can fall back to gzip compression" do
        helper.request.env["HTTP_ACCEPT_ENCODING"] = "gzip"
        link = helper.preload_script("start-discourse")
        expect(link).to eq(
          script_tag(
            "https://s3cdn.com/assets/start-discourse.gz.js",
            "start-discourse",
            helper.csp_nonce_placeholder,
          ),
        )
      end

      it "gives s3 cdn even if asset host is set" do
        set_cdn_url "https://awesome.com"
        link = helper.preload_script("start-discourse")

        expect(link).to eq(
          script_tag(
            "https://s3cdn.com/assets/start-discourse.js",
            "start-discourse",
            helper.csp_nonce_placeholder,
          ),
        )
      end

      it "gives s3 cdn but without brotli/gzip extensions for theme tests assets" do
        helper.request.env["HTTP_ACCEPT_ENCODING"] = "gzip, br"
        link = helper.preload_script("discourse/tests/theme_qunit_ember_jquery")
        expect(link).to eq(
          script_tag(
            "https://s3cdn.com/assets/discourse/tests/theme_qunit_ember_jquery.js",
            "discourse/tests/theme_qunit_ember_jquery",
            helper.csp_nonce_placeholder,
          ),
        )
      end

      it "uses separate asset CDN if configured" do
        global_setting :s3_asset_cdn_url, "https://s3-asset-cdn.example.com"
        expect(helper.preload_script("start-discourse")).to include(
          "https://s3-asset-cdn.example.com/assets/start-discourse.js",
        )
      end
    end
  end

  describe "add_resource_preload_list" do
    it "adds resources to the preload list" do
      add_resource_preload_list("/assets/start-discourse.js", "script")
      add_resource_preload_list("/assets/discourse.css", "style")

      expect(controller.instance_variable_get(:@asset_preload_links).size).to eq(2)
    end

    it "adds resources to the preload list when preload_script is called" do
      helper.preload_script("start-discourse")

      expect(controller.instance_variable_get(:@asset_preload_links).size).to eq(1)
    end

    it "adds resources to the preload list when discourse_stylesheet_link_tag is called" do
      helper.discourse_stylesheet_link_tag(:desktop)

      expect(controller.instance_variable_get(:@asset_preload_links).size).to eq(1)
    end

    it "adds resources as the correct type" do
      helper.discourse_stylesheet_link_tag(:desktop)
      helper.preload_script("start-discourse")

      expect(controller.instance_variable_get(:@asset_preload_links)[0]).to match(/as="style"/)
      expect(controller.instance_variable_get(:@asset_preload_links)[1]).to match(/as="script"/)
    end
  end

  describe "escape_unicode" do
    it "encodes tags" do
      expect(helper.escape_unicode("<tag>")).to eq("\u003ctag>")
    end
    it "survives junk text" do
      expect(helper.escape_unicode("hello \xc3\x28 world")).to match(/hello.*world/)
    end
  end

  describe "render_sitelinks_search_tag" do
    context "for non-subfolder install" do
      context "when on homepage" do
        it "will return sitelinks search tag" do
          helper.stubs(:current_page?).returns(false)
          helper.stubs(:current_page?).with("/").returns(true)

          sitelinks_search_tag =
            JSON.parse(
              helper
                .render_sitelinks_search_tag
                .gsub('<script type="application/ld+json">', "")
                .gsub("</script>", ""),
            )

          expect(sitelinks_search_tag["@type"]).to eq("WebSite")
          expect(sitelinks_search_tag["potentialAction"]["@type"]).to eq("SearchAction")
          expect(sitelinks_search_tag["name"]).to eq(SiteSetting.title)
          expect(sitelinks_search_tag["url"]).to eq(Discourse.base_url)
        end
      end
      context "when not on homepage" do
        it "will not return sitelinks search tag" do
          helper.stubs(:current_page?).returns(true)
          helper.stubs(:current_page?).with("/").returns(false)
          helper.stubs(:current_page?).with(Discourse.base_path).returns(false)
          expect(helper.render_sitelinks_search_tag).to be_nil
        end
      end
    end
    context "for subfolder install" do
      context "when on homepage" do
        it "will return sitelinks search tag" do
          Discourse.stubs(:base_path).returns("/subfolder-base-path/")
          helper.stubs(:current_page?).returns(false)
          helper.stubs(:current_page?).with(Discourse.base_path).returns(true)
          expect(helper.render_sitelinks_search_tag).to include('"@type":"SearchAction"')
          expect(helper.render_sitelinks_search_tag).to include("subfolder-base-path")
        end
      end
      context "when not on homepage" do
        it "will not return sitelinks search tag" do
          Discourse.stubs(:base_path).returns("/subfolder-base-path/")
          helper.stubs(:current_page?).returns(true)
          helper.stubs(:current_page?).with("/").returns(false)
          helper.stubs(:current_page?).with(Discourse.base_path).returns(false)
          expect(helper.render_sitelinks_search_tag).to be_nil
        end
      end
    end
  end

  describe "application_logo_url" do
    context "when a dark color scheme is active" do
      before do
        dark_theme =
          Theme.create(
            name: "Dark",
            user_id: Discourse::SYSTEM_USER_ID,
            color_scheme_id: ColorScheme.find_by(base_scheme_id: "Dark").id,
          )
        helper.request.env[:resolved_theme_id] = dark_theme.id
      end

      context "when on desktop" do
        before { session[:mobile_view] = "0" }

        context "when logo_dark is not set" do
          it "will return site_logo_url instead" do
            expect(helper.application_logo_url).to eq(SiteSetting.site_logo_url)
          end
        end

        context "when logo_dark is set" do
          before { SiteSetting.logo_dark = Fabricate(:upload, url: "/images/logo-dark.png") }

          it "will return site_logo_dark_url" do
            expect(helper.application_logo_url).to eq(SiteSetting.site_logo_dark_url)
          end
        end
      end

      context "when on mobile" do
        before { session[:mobile_view] = "1" }

        context "when mobile_logo_dark is not set" do
          it "will return site_mobile_logo_url instead" do
            expect(helper.application_logo_url).to eq(SiteSetting.site_mobile_logo_url)
          end
        end

        context "when mobile_logo_dark is set" do
          before do
            SiteSetting.mobile_logo_dark = Fabricate(:upload, url: "/images/mobile-logo-dark.png")
          end

          it "will return site_mobile_logo_dark_url" do
            expect(helper.application_logo_url).to eq(SiteSetting.site_mobile_logo_dark_url)
          end
        end
      end
    end
  end

  describe "application_logo_dark_url" do
    context "when dark theme is not present" do
      context "when dark logo is not present" do
        it "should return nothing" do
          expect(helper.application_logo_dark_url.present?).to eq(false)
        end
      end
    end

    context "when dark theme is present" do
      before do
        _dark_theme =
          Theme.create(
            name: "Dark",
            user_id: Discourse::SYSTEM_USER_ID,
            color_scheme_id: ColorScheme.find_by(base_scheme_id: "Dark").id,
          )
      end

      context "when dark logo is not present" do
        it "should return nothing" do
          expect(helper.application_logo_dark_url.present?).to eq(false)
        end
      end

      context "when dark logo is present" do
        before { SiteSetting.logo_dark = Fabricate(:upload, url: "/images/logo-dark.png") }

        it "should return correct url" do
          expect(helper.application_logo_dark_url).to eq(SiteSetting.site_logo_dark_url)
        end
      end
    end

    context "when dark theme is present and selected" do
      before do
        dark_theme =
          Theme.create(
            name: "Dark",
            user_id: Discourse::SYSTEM_USER_ID,
            color_scheme_id: ColorScheme.find_by(base_scheme_id: "Dark").id,
          )
        helper.request.env[:resolved_theme_id] = dark_theme.id
        SiteSetting.logo_dark = Fabricate(:upload, url: "/images/logo-dark.png")
      end

      it "should return nothing" do
        expect(helper.application_logo_url).to eq(SiteSetting.site_logo_dark_url)
        expect(helper.application_logo_dark_url.present?).to eq(false)
      end
    end
  end

  describe "#mobile_view?" do
    context "when enable_mobile_theme is true" do
      before { SiteSetting.enable_mobile_theme = true }

      it "is true if mobile_view is '1' in the session" do
        session[:mobile_view] = "1"
        expect(helper.mobile_view?).to eq(true)
      end

      it "is false if mobile_view is '0' in the session" do
        session[:mobile_view] = "0"
        expect(helper.mobile_view?).to eq(false)
      end

      context "when mobile_view session is cleared" do
        before { params[:mobile_view] = "auto" }

        it "is false if user agent is not mobile" do
          session[:mobile_view] = "1"
          controller
            .request
            .stubs(:user_agent)
            .returns(
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.87 Safari/537.36",
            )
          expect(helper.mobile_view?).to be_falsey
        end

        it "is true for iPhone" do
          session[:mobile_view] = "0"
          controller
            .request
            .stubs(:user_agent)
            .returns(
              "Mozilla/5.0 (iPhone; CPU iPhone OS 9_2_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13D15 Safari/601.1",
            )
          expect(helper.mobile_view?).to eq(true)
        end
      end

      context "when mobile_view is not set" do
        it "is false if user agent is not mobile" do
          controller
            .request
            .stubs(:user_agent)
            .returns(
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.87 Safari/537.36",
            )
          expect(helper.mobile_view?).to be_falsey
        end

        it "is true for iPhone" do
          controller
            .request
            .stubs(:user_agent)
            .returns(
              "Mozilla/5.0 (iPhone; CPU iPhone OS 9_2_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13D15 Safari/601.1",
            )
          expect(helper.mobile_view?).to eq(true)
        end

        it "is true for Android Samsung Galaxy" do
          controller
            .request
            .stubs(:user_agent)
            .returns(
              "Mozilla/5.0 (Linux; Android 5.0.2; SAMSUNG SM-G925F Build/LRX22G) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/4.0 Chrome/44.0.2403.133 Mobile Safari/537.36",
            )
          expect(helper.mobile_view?).to eq(true)
        end

        it "is true for Android Google Nexus 5X" do
          controller
            .request
            .stubs(:user_agent)
            .returns(
              "Mozilla/5.0 (Linux; Android 6.0; Nexus 5X Build/MDB08I) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2490.43 Mobile Safari/537.36",
            )
          expect(helper.mobile_view?).to eq(true)
        end

        it "is false for iPad" do
          controller
            .request
            .stubs(:user_agent)
            .returns(
              "Mozilla/5.0 (iPad; CPU OS 9_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B14 3 Safari/601.1",
            )
          expect(helper.mobile_view?).to eq(false)
        end

        it "is false for Nexus 10 tablet" do
          controller
            .request
            .stubs(:user_agent)
            .returns(
              "Mozilla/5.0 (Linux; Android 5.1.1; Nexus 10 Build/LMY49G) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.91 Safari/537.36",
            )
          expect(helper.mobile_view?).to be_falsey
        end

        it "is false for Nexus 7 tablet" do
          controller
            .request
            .stubs(:user_agent)
            .returns(
              "Mozilla/5.0 (Linux; Android 6.0.1; Nexus 7 Build/MMB29Q) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.91 Safari/537.36",
            )
          expect(helper.mobile_view?).to be_falsey
        end
      end
    end

    context "when enable_mobile_theme is false" do
      before { SiteSetting.enable_mobile_theme = false }

      it "is false if mobile_view is '1' in the session" do
        session[:mobile_view] = "1"
        expect(helper.mobile_view?).to eq(false)
      end

      it "is false if mobile_view is '0' in the session" do
        session[:mobile_view] = "0"
        expect(helper.mobile_view?).to eq(false)
      end

      context "when mobile_view is not set" do
        it "is false if user agent is not mobile" do
          controller
            .request
            .stubs(:user_agent)
            .returns(
              "Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.17 Safari/537.36",
            )
          expect(helper.mobile_view?).to eq(false)
        end

        it "is false for iPhone" do
          controller
            .request
            .stubs(:user_agent)
            .returns(
              "Mozilla/5.0 (iPhone; U; ru; CPU iPhone OS 4_2_1 like Mac OS X; ru) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8C148a Safari/6533.18.5",
            )
          expect(helper.mobile_view?).to eq(false)
        end
      end
    end
  end

  describe "#html_classes" do
    fab!(:user)

    it "includes 'rtl' when the I18n.locale is rtl" do
      I18n.stubs(:locale).returns(:he)
      expect(helper.html_classes.split(" ")).to include("rtl")
    end

    it "returns an empty string when the I18n.locale is not rtl" do
      I18n.stubs(:locale).returns(:zh_TW)
      expect(helper.html_classes.split(" ")).not_to include("rtl")
    end

    describe "text size" do
      context "with a user option" do
        before do
          user.user_option.text_size = "larger"
          user.user_option.save!
          helper.request.env[Auth::DefaultCurrentUserProvider::CURRENT_USER_KEY] = user
        end

        it "ignores invalid text sizes" do
          helper.request.cookies["text_size"] = "invalid"
          expect(helper.html_classes.split(" ")).to include("text-size-larger")
        end

        it "ignores missing text size" do
          helper.request.cookies["text_size"] = nil
          expect(helper.html_classes.split(" ")).to include("text-size-larger")
        end

        it "ignores cookies with lower sequence" do
          user.user_option.update!(text_size_seq: 2)

          helper.request.cookies["text_size"] = "normal|1"
          expect(helper.html_classes.split(" ")).to include("text-size-larger")
        end

        it "prioritises the cookie specified text size" do
          user.user_option.update!(text_size_seq: 2)

          helper.request.cookies["text_size"] = "largest|4"
          expect(helper.html_classes.split(" ")).to include("text-size-largest")
        end

        it "includes the user specified text size" do
          helper.request.env[Auth::DefaultCurrentUserProvider::CURRENT_USER_KEY] = user
          expect(helper.html_classes.split(" ")).to include("text-size-larger")
        end
      end

      it "falls back to the default text size for anon" do
        expect(helper.html_classes.split(" ")).to include("text-size-normal")
        SiteSetting.default_text_size = "largest"
        expect(helper.html_classes.split(" ")).to include("text-size-largest")
      end
    end

    it "includes 'anon' for anonymous users and excludes when logged in" do
      expect(helper.html_classes.split(" ")).to include("anon")
      helper.request.env[Auth::DefaultCurrentUserProvider::CURRENT_USER_KEY] = user
      expect(helper.html_classes.split(" ")).not_to include("anon")
    end
  end

  describe "gsub_emoji_to_unicode" do
    it "converts all emoji to unicode" do
      expect(
        helper.gsub_emoji_to_unicode("Boat Talk: my :sailboat: boat: why is it so slow? :snail:"),
      ).to eq("Boat Talk: my ⛵ boat: why is it so slow? 🐌")
    end
  end

  describe "preloaded_json" do
    it "returns empty JSON if preloaded is empty" do
      @preloaded = nil
      expect(helper.preloaded_json).to eq("{}")
    end

    it "escapes and strips invalid unicode and strips in json body" do
      @preloaded = { test: %{["< \x80"]} }
      expect(helper.preloaded_json).to eq(%{{"test":"[\\"\\u003c \uFFFD\\"]"}})
    end
  end

  describe "client_side_setup_data" do
    context "when Rails.env.development? is true" do
      before { Rails.env.stubs(:development?).returns(true) }

      it "returns the correct service worker url" do
        expect(helper.client_side_setup_data[:service_worker_url]).to eq("service-worker.js")
      end

      it "returns the svg_icon_list in the setup data" do
        expect(helper.client_side_setup_data[:svg_icon_list]).not_to eq(nil)
      end

      it "does not return debug_preloaded_app_data without the env var" do
        expect(helper.client_side_setup_data.key?(:debug_preloaded_app_data)).to eq(false)
      end

      context "if the DEBUG_PRELOADED_APP_DATA env var is provided" do
        before { ENV["DEBUG_PRELOADED_APP_DATA"] = "true" }

        it "returns that key as true" do
          expect(helper.client_side_setup_data[:debug_preloaded_app_data]).to eq(true)
        end
      end
    end
  end

  describe "crawlable_meta_data" do
    it "Supports ASCII URLs with odd chars" do
      result =
        helper.crawlable_meta_data(
          url: (+"http://localhost/ión").force_encoding("ASCII-8BIT").freeze,
        )

      expect(result).to include("ión")
    end

    context "with opengraph image" do
      it "returns the correct image" do
        SiteSetting.opengraph_image = Fabricate(:upload, url: "/images/og-image.png")

        SiteSetting.twitter_summary_large_image = Fabricate(:upload, url: "/images/twitter.png")

        SiteSetting.large_icon = Fabricate(:upload, url: "/images/large_icon.png")

        SiteSetting.apple_touch_icon =
          Fabricate(:upload, url: "/images/default-apple-touch-icon.png")

        SiteSetting.logo = Fabricate(:upload, url: "/images/d-logo-sketch.png")

        expect(helper.crawlable_meta_data(image: "some-image.png")).to include("some-image.png")

        expect(helper.crawlable_meta_data).to include(SiteSetting.site_opengraph_image_url)

        SiteSetting.opengraph_image = nil

        expect(helper.crawlable_meta_data).to include(
          SiteSetting.site_twitter_summary_large_image_url,
        )

        SiteSetting.twitter_summary_large_image = nil

        expect(helper.crawlable_meta_data).to include(SiteSetting.site_large_icon_url)

        SiteSetting.large_icon = nil
        SiteSetting.logo_small = nil

        expect(helper.crawlable_meta_data).to include(SiteSetting.site_logo_url)

        SiteSetting.logo = nil

        expect(helper.crawlable_meta_data).to include(
          Upload.find(SiteIconManager::SKETCH_LOGO_ID).url,
        )
      end

      it "does not allow SVG images for twitter:image, falls back to site logo or nothing if site logo is SVG too" do
        SiteSetting.logo = Fabricate(:upload, url: "/images/d-logo-sketch.png")
        SiteSetting.opengraph_image = Fabricate(:upload, url: "/images/og-image.png")

        expect(helper.crawlable_meta_data).to include(<<~HTML)
        <meta name=\"twitter:image\" content=\"#{SiteSetting.site_opengraph_image_url}\" />
        HTML

        SiteSetting.opengraph_image = Fabricate(:upload, url: "/images/og-image.svg")

        expect(helper.crawlable_meta_data).to include(<<~HTML)
        <meta name=\"twitter:image\" content=\"#{SiteSetting.site_logo_url}\" />
        HTML

        SiteSetting.twitter_summary_large_image = Fabricate(:upload, url: "/images/twitter.png")

        expect(helper.crawlable_meta_data).to include(<<~HTML)
        <meta name=\"twitter:image\" content=\"#{SiteSetting.site_twitter_summary_large_image_url}\" />
        HTML

        SiteSetting.twitter_summary_large_image = Fabricate(:upload, url: "/images/twitter.svg")

        expect(helper.crawlable_meta_data).to include(<<~HTML)
        <meta name=\"twitter:image\" content=\"#{SiteSetting.site_logo_url}\" />
        HTML

        SiteSetting.logo = Fabricate(:upload, url: "/images/d-logo-sketch.svg")

        expect(helper.crawlable_meta_data).not_to include("twitter:image")
      end
    end

    context "with breadcrumbs" do
      subject(:metadata) { helper.crawlable_meta_data(breadcrumbs: breadcrumbs) }

      let(:breadcrumbs) do
        [{ name: "section1", color: "ff0000" }, { name: "section2", color: "0000ff" }]
      end
      let(:tags) { <<~HTML.strip }
        <meta property="og:article:section" content="section1" />
        <meta property="og:article:section:color" content="ff0000" />
        <meta property="og:article:section" content="section2" />
        <meta property="og:article:section:color" content="0000ff" />
        HTML

      it "generates section and color tags" do
        expect(metadata).to include tags
      end
    end

    context "with tags" do
      subject(:metadata) { helper.crawlable_meta_data(tags: tags) }

      let(:tags) { %w[tag1 tag2] }
      let(:output_tags) { <<~HTML.strip }
        <meta property="og:article:tag" content="tag1" />
        <meta property="og:article:tag" content="tag2" />
        HTML

      it "generates tag tags" do
        expect(metadata).to include output_tags
      end
    end

    context "with custom site name" do
      before { SiteSetting.title = "Default Site Title" }

      it "uses the provided site name in og:site_name" do
        custom_site_name = "Custom Site Name"
        result = helper.crawlable_meta_data(site_name: custom_site_name)

        expect(result).to include(
          "<meta property=\"og:site_name\" content=\"#{custom_site_name}\" />",
        )
      end

      it "falls back to the default site title if no custom site name is provided" do
        result = helper.crawlable_meta_data

        expect(result).to include(
          "<meta property=\"og:site_name\" content=\"#{SiteSetting.title}\" />",
        )
      end
    end
  end

  describe "discourse_color_scheme_stylesheets" do
    fab!(:user)

    it "returns a stylesheet link tag by default" do
      cs_stylesheets = helper.discourse_color_scheme_stylesheets
      expect(cs_stylesheets).to include("stylesheets/color_definitions")
    end

    it "returns two color scheme link tags when dark mode is enabled" do
      SiteSetting.default_dark_mode_color_scheme_id = ColorScheme.where(name: "Dark").pick(:id)
      cs_stylesheets = helper.discourse_color_scheme_stylesheets

      expect(cs_stylesheets).to include("(prefers-color-scheme: dark)")
      expect(cs_stylesheets.scan("stylesheets/color_definitions").size).to eq(2)
    end

    it "handles a missing dark color scheme gracefully" do
      scheme = ColorScheme.create!(name: "pyramid")
      SiteSetting.default_dark_mode_color_scheme_id = scheme.id
      scheme.destroy!
      cs_stylesheets = helper.discourse_color_scheme_stylesheets

      expect(cs_stylesheets).to include("stylesheets/color_definitions")
      expect(cs_stylesheets).not_to include("(prefers-color-scheme: dark)")
    end

    context "with custom light scheme" do
      before do
        @new_cs = Fabricate(:color_scheme, name: "Flamboyant")
        user.user_option.color_scheme_id = @new_cs.id
        user.user_option.save!
        helper.request.env[Auth::DefaultCurrentUserProvider::CURRENT_USER_KEY] = user
      end

      it "returns color scheme from user option value" do
        color_stylesheets = helper.discourse_color_scheme_stylesheets
        expect(color_stylesheets).to include("color_definitions_flamboyant")
      end

      it "returns color scheme from cookie value" do
        cs = ColorScheme.where(name: "Dark").first
        helper.request.cookies["color_scheme_id"] = cs.id

        color_stylesheets = helper.discourse_color_scheme_stylesheets

        expect(color_stylesheets).to include("color_definitions_dark")
        expect(color_stylesheets).not_to include("color_definitions_flamboyant")
      end

      it "falls back to base scheme with invalid cookie value" do
        helper.request.cookies["color_scheme_id"] = -50

        color_stylesheets = helper.discourse_color_scheme_stylesheets
        expect(color_stylesheets).not_to include("color_definitions_flamboyant")
        expect(color_stylesheets).to include("color_definitions_base")
      end
    end

    context "with dark scheme with user option and/or cookies" do
      before do
        user.user_option.dark_scheme_id = -1
        user.user_option.save!
        helper.request.env[Auth::DefaultCurrentUserProvider::CURRENT_USER_KEY] = user
        @new_cs = Fabricate(:color_scheme, name: "Custom Color Scheme")

        SiteSetting.default_dark_mode_color_scheme_id = ColorScheme.where(name: "Dark").pick(:id)
      end

      it "returns no dark scheme stylesheet when user has disabled that option" do
        color_stylesheets = helper.discourse_color_scheme_stylesheets

        expect(color_stylesheets).to include("stylesheets/color_definitions")
        expect(color_stylesheets).not_to include("(prefers-color-scheme: dark)")
      end

      it "returns user-selected dark color scheme stylesheet" do
        user.user_option.update!(dark_scheme_id: @new_cs.id)

        color_stylesheets = helper.discourse_color_scheme_stylesheets
        expect(color_stylesheets).to include("(prefers-color-scheme: dark)")
        expect(color_stylesheets).to include("custom-color-scheme")
      end

      it "respects cookie value over user option for dark color scheme" do
        helper.request.cookies["dark_scheme_id"] = @new_cs.id

        color_stylesheets = helper.discourse_color_scheme_stylesheets
        expect(color_stylesheets).to include("(prefers-color-scheme: dark)")
        expect(color_stylesheets).to include("custom-color-scheme")
      end

      it "returns no dark scheme with invalid cookie value" do
        helper.request.cookies["dark_scheme_id"] = -10

        color_stylesheets = helper.discourse_color_scheme_stylesheets
        expect(color_stylesheets).not_to include("(prefers-color-scheme: dark)")
      end
    end
  end

  describe "dark_color_scheme?" do
    it "returns false for the base color scheme" do
      expect(helper.dark_color_scheme?).to eq(false)
    end

    it "works correctly for a dark scheme" do
      dark_theme =
        Theme.create(
          name: "Dark",
          user_id: Discourse::SYSTEM_USER_ID,
          color_scheme_id: ColorScheme.find_by(base_scheme_id: "Dark").id,
        )
      helper.request.env[:resolved_theme_id] = dark_theme.id

      expect(helper.dark_color_scheme?).to eq(true)
    end
  end

  describe "html_lang" do
    fab!(:user)

    before do
      I18n.locale = :de
      SiteSetting.default_locale = :fr
    end

    it "returns default locale if no request" do
      helper.request = nil
      expect(helper.html_lang).to eq(SiteSetting.default_locale)
    end

    it "returns current user locale if request" do
      helper.request.env[Auth::DefaultCurrentUserProvider::CURRENT_USER_KEY] = user
      expect(helper.html_lang).to eq(I18n.locale.to_s)
    end
  end

  describe "#discourse_theme_color_meta_tags" do
    before do
      light = Fabricate(:color_scheme)
      light.color_scheme_colors << ColorSchemeColor.new(name: "header_background", hex: "abcdef")
      light.save!
      helper.request.cookies["color_scheme_id"] = light.id

      dark = Fabricate(:color_scheme)
      dark.color_scheme_colors << ColorSchemeColor.new(name: "header_background", hex: "defabc")
      dark.save!
      helper.request.cookies["dark_scheme_id"] = dark.id
    end

    it "renders theme-color meta for the light scheme with media=(prefers-color-scheme: light) and another one for the dark scheme with media=(prefers-color-scheme: dark)" do
      expect(helper.discourse_theme_color_meta_tags).to eq(<<~HTML)
        <meta name="theme-color" media="(prefers-color-scheme: light)" content="#abcdef">
        <meta name="theme-color" media="(prefers-color-scheme: dark)" content="#defabc">
      HTML
    end

    it "doesn't render theme-color meta tag for the dark scheme if none is set" do
      SiteSetting.default_dark_mode_color_scheme_id = -1
      helper.request.cookies.delete("dark_scheme_id")

      expect(helper.discourse_theme_color_meta_tags).to eq(<<~HTML)
        <meta name="theme-color" media="all" content="#abcdef">
      HTML
    end
  end

  describe "#discourse_color_scheme_meta_tag" do
    before do
      light = Fabricate(:color_scheme)
      light.save!
      helper.request.cookies["color_scheme_id"] = light.id
    end

    it "renders a 'light' color-scheme if no dark scheme is set" do
      SiteSetting.default_dark_mode_color_scheme_id = -1

      expect(helper.discourse_color_scheme_meta_tag).to eq(<<~HTML)
        <meta name="color-scheme" content="light">
      HTML
    end

    it "renders a 'light dark' color-scheme if a dark scheme is set" do
      dark = Fabricate(:color_scheme)
      dark.save!
      helper.request.cookies["dark_scheme_id"] = dark.id

      expect(helper.discourse_color_scheme_meta_tag).to eq(<<~HTML)
        <meta name="color-scheme" content="light dark">
      HTML
    end
  end
end
