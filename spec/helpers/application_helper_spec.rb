# coding: utf-8
# frozen_string_literal: true

require 'rails_helper'

describe ApplicationHelper do

  describe "preload_script" do
    def preload_link(url)
      <<~HTML
          <link rel="preload" href="#{url}" as="script">
          <script src="#{url}"></script>
      HTML
    end

    it "provides brotli links to brotli cdn" do
      set_cdn_url "https://awesome.com"

      helper.request.env["HTTP_ACCEPT_ENCODING"] = 'br'
      link = helper.preload_script('application')

      expect(link).to eq(preload_link("https://awesome.com/brotli_asset/application.js"))
    end

    context "with s3 CDN" do
      before do
        global_setting :s3_bucket, 'test_bucket'
        global_setting :s3_region, 'ap-australia'
        global_setting :s3_access_key_id, '123'
        global_setting :s3_secret_access_key, '123'
        global_setting :s3_cdn_url, 'https://s3cdn.com'
      end

      it "deals correctly with subfolder" do
        set_subfolder "/community"
        expect(helper.preload_script("application")).to include('https://s3cdn.com/assets/application.js')
      end

      it "replaces cdn URLs with s3 cdn subfolder paths" do
        global_setting :s3_cdn_url, 'https://s3cdn.com/s3_subpath'
        set_cdn_url "https://awesome.com"
        set_subfolder "/community"
        expect(helper.preload_script("application")).to include('https://s3cdn.com/s3_subpath/assets/application.js')
      end

      it "returns magic brotli mangling for brotli requests" do

        helper.request.env["HTTP_ACCEPT_ENCODING"] = 'br'
        link = helper.preload_script('application')

        expect(link).to eq(preload_link("https://s3cdn.com/assets/application.br.js"))
      end

      it "gives s3 cdn if asset host is not set" do
        link = helper.preload_script('application')

        expect(link).to eq(preload_link("https://s3cdn.com/assets/application.js"))
      end

      it "can fall back to gzip compression" do
        helper.request.env["HTTP_ACCEPT_ENCODING"] = 'gzip'
        link = helper.preload_script('application')
        expect(link).to eq(preload_link("https://s3cdn.com/assets/application.gz.js"))
      end

      it "gives s3 cdn even if asset host is set" do
        set_cdn_url "https://awesome.com"
        link = helper.preload_script('application')

        expect(link).to eq(preload_link("https://s3cdn.com/assets/application.js"))
      end
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

  describe "mobile_view?" do
    context "enable_mobile_theme is true" do
      before do
        SiteSetting.enable_mobile_theme = true
      end

      it "is true if mobile_view is '1' in the session" do
        session[:mobile_view] = '1'
        expect(helper.mobile_view?).to eq(true)
      end

      it "is false if mobile_view is '0' in the session" do
        session[:mobile_view] = '0'
        expect(helper.mobile_view?).to eq(false)
      end

      context "mobile_view session is cleared" do
        before do
          params[:mobile_view] = 'auto'
        end

        it "is false if user agent is not mobile" do
          session[:mobile_view] = '1'
          controller.request.stubs(:user_agent).returns('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.87 Safari/537.36')
          expect(helper.mobile_view?).to be_falsey
        end

        it "is true for iPhone" do
          session[:mobile_view] = '0'
          controller.request.stubs(:user_agent).returns('Mozilla/5.0 (iPhone; CPU iPhone OS 9_2_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13D15 Safari/601.1')
          expect(helper.mobile_view?).to eq(true)
        end
      end

      context "mobile_view is not set" do
        it "is false if user agent is not mobile" do
          controller.request.stubs(:user_agent).returns('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.87 Safari/537.36')
          expect(helper.mobile_view?).to be_falsey
        end

        it "is true for iPhone" do
          controller.request.stubs(:user_agent).returns('Mozilla/5.0 (iPhone; CPU iPhone OS 9_2_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13D15 Safari/601.1')
          expect(helper.mobile_view?).to eq(true)
        end

        it "is true for Android Samsung Galaxy" do
          controller.request.stubs(:user_agent).returns('Mozilla/5.0 (Linux; Android 5.0.2; SAMSUNG SM-G925F Build/LRX22G) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/4.0 Chrome/44.0.2403.133 Mobile Safari/537.36')
          expect(helper.mobile_view?).to eq(true)
        end

        it "is true for Android Google Nexus 5X" do
          controller.request.stubs(:user_agent).returns('Mozilla/5.0 (Linux; Android 6.0; Nexus 5X Build/MDB08I) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/46.0.2490.43 Mobile Safari/537.36')
          expect(helper.mobile_view?).to eq(true)
        end

        it "is false for iPad" do
          controller.request.stubs(:user_agent).returns("Mozilla/5.0 (iPad; CPU OS 9_1 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Version/9.0 Mobile/13B14 3 Safari/601.1")
          expect(helper.mobile_view?).to eq(false)
        end

        it "is false for Nexus 10 tablet" do
          controller.request.stubs(:user_agent).returns("Mozilla/5.0 (Linux; Android 5.1.1; Nexus 10 Build/LMY49G) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.91 Safari/537.36")
          expect(helper.mobile_view?).to be_falsey
        end

        it "is false for Nexus 7 tablet" do
          controller.request.stubs(:user_agent).returns("Mozilla/5.0 (Linux; Android 6.0.1; Nexus 7 Build/MMB29Q) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.91 Safari/537.36")
          expect(helper.mobile_view?).to be_falsey
        end
      end
    end

    context "enable_mobile_theme is false" do
      before do
        SiteSetting.enable_mobile_theme = false
      end

      it "is false if mobile_view is '1' in the session" do
        session[:mobile_view] = '1'
        expect(helper.mobile_view?).to eq(false)
      end

      it "is false if mobile_view is '0' in the session" do
        session[:mobile_view] = '0'
        expect(helper.mobile_view?).to eq(false)
      end

      context "mobile_view is not set" do
        it "is false if user agent is not mobile" do
          controller.request.stubs(:user_agent).returns('Mozilla/5.0 (Windows NT 6.2; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.17 Safari/537.36')
          expect(helper.mobile_view?).to eq(false)
        end

        it "is false for iPhone" do
          controller.request.stubs(:user_agent).returns('Mozilla/5.0 (iPhone; U; ru; CPU iPhone OS 4_2_1 like Mac OS X; ru) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8C148a Safari/6533.18.5')
          expect(helper.mobile_view?).to eq(false)
        end
      end
    end
  end

  describe '#html_classes' do
    fab!(:user) { Fabricate(:user) }

    it "includes 'rtl' when the I18n.locale is rtl" do
      I18n.stubs(:locale).returns(:he)
      expect(helper.html_classes.split(" ")).to include('rtl')
    end

    it 'returns an empty string when the I18n.locale is not rtl' do
      I18n.stubs(:locale).returns(:zh_TW)
      expect(helper.html_classes.split(" ")).not_to include('rtl')
    end

    describe 'text size' do
      context "with a user option" do
        before do
          user.user_option.text_size = "larger"
          user.user_option.save!
          helper.request.env[Auth::DefaultCurrentUserProvider::CURRENT_USER_KEY] = user
        end

        it 'ignores invalid text sizes' do
          helper.request.cookies["text_size"] = "invalid"
          expect(helper.html_classes.split(" ")).to include('text-size-larger')
        end

        it 'ignores missing text size' do
          helper.request.cookies["text_size"] = nil
          expect(helper.html_classes.split(" ")).to include('text-size-larger')
        end

        it 'ignores cookies with lower sequence' do
          user.user_option.update!(text_size_seq: 2)

          helper.request.cookies["text_size"] = "normal|1"
          expect(helper.html_classes.split(" ")).to include('text-size-larger')
        end

        it 'prioritises the cookie specified text size' do
          user.user_option.update!(text_size_seq: 2)

          helper.request.cookies["text_size"] = "largest|4"
          expect(helper.html_classes.split(" ")).to include('text-size-largest')
        end

        it 'includes the user specified text size' do
          helper.request.env[Auth::DefaultCurrentUserProvider::CURRENT_USER_KEY] = user
          expect(helper.html_classes.split(" ")).to include('text-size-larger')
        end
      end

      it 'falls back to the default text size for anon' do
        expect(helper.html_classes.split(" ")).to include('text-size-normal')
        SiteSetting.default_text_size = "largest"
        expect(helper.html_classes.split(" ")).to include('text-size-largest')
      end
    end

    it "includes 'anon' for anonymous users and excludes when logged in" do
      expect(helper.html_classes.split(" ")).to include('anon')
      helper.request.env[Auth::DefaultCurrentUserProvider::CURRENT_USER_KEY] = user
      expect(helper.html_classes.split(" ")).not_to include('anon')
    end
  end

  describe 'gsub_emoji_to_unicode' do
    it "converts all emoji to unicode" do
      expect(helper.gsub_emoji_to_unicode('Boat Talk: my :sailboat: boat: why is it so slow? :snail:')).to eq("Boat Talk: my ⛵ boat: why is it so slow? 🐌")
    end
  end

  describe 'preloaded_json' do
    it 'returns empty JSON if preloaded is empty' do
      @preloaded = nil
      expect(helper.preloaded_json).to eq('{}')
    end

    it 'escapes and strips invalid unicode and strips in json body' do
      @preloaded = { test: %{["< \x80"]} }
      expect(helper.preloaded_json).to eq(%{{"test":"[\\"\\u003c \uFFFD\\"]"}})
    end
  end

  describe "client_side_setup_data" do
    context "when Rails.env.development? is true" do
      before do
        Rails.env.stubs(:development?).returns(true)
      end

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
        before do
          ENV['DEBUG_PRELOADED_APP_DATA'] = 'true'
        end

        it "returns that key as true" do
          expect(helper.client_side_setup_data[:debug_preloaded_app_data]).to eq(true)
        end
      end
    end
  end

  describe 'crawlable_meta_data' do
    context "opengraph image" do
      it 'returns the correct image' do
        SiteSetting.opengraph_image = Fabricate(:upload,
          url: '/images/og-image.png'
        )

        SiteSetting.twitter_summary_large_image = Fabricate(:upload,
          url: '/images/twitter.png'
        )

        SiteSetting.large_icon = Fabricate(:upload,
          url: '/images/large_icon.png'
        )

        SiteSetting.apple_touch_icon = Fabricate(:upload,
          url: '/images/default-apple-touch-icon.png'
        )

        SiteSetting.logo = Fabricate(:upload, url: '/images/d-logo-sketch.png')

        expect(
          helper.crawlable_meta_data(image: "some-image.png")
        ).to include("some-image.png")

        expect(helper.crawlable_meta_data).to include(
          SiteSetting.site_opengraph_image_url
        )

        SiteSetting.opengraph_image = nil

        expect(helper.crawlable_meta_data).to include(
          SiteSetting.site_twitter_summary_large_image_url
        )

        SiteSetting.twitter_summary_large_image = nil

        expect(helper.crawlable_meta_data).to include(
          SiteSetting.site_large_icon_url
        )

        SiteSetting.large_icon = nil
        SiteSetting.logo_small = nil

        expect(helper.crawlable_meta_data).to include(SiteSetting.site_logo_url)

        SiteSetting.logo = nil
        SiteSetting.logo_url = nil

        expect(helper.crawlable_meta_data).to include(Upload.find(SiteIconManager::SKETCH_LOGO_ID).url)
      end
    end
  end
end
