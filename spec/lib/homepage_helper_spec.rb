# frozen_string_literal: true

RSpec.describe HomepageHelper do
  describe "resolver" do
    fab!(:user)

    it "returns latest by default" do
      expect(HomepageHelper.resolve).to eq("latest")
    end

    context "when a theme has a custom homepage" do
      before { ThemeModifierHelper.any_instance.stubs(:custom_homepage).returns(true) }

      it "returns custom" do
        expect(HomepageHelper.resolve).to eq("custom")
      end

      it "returns the configured crawler route for crawler requests" do
        SiteSetting.custom_homepage_crawler_route = "categories"
        request = ActionDispatch::TestRequest.create("HTTP_USER_AGENT" => "Googlebot")

        expect(HomepageHelper.resolve(request)).to eq("categories")
      end
    end

    context "when a plugin modifies the custom_homepage_enabled to true" do
      before do
        DiscoursePluginRegistry
          .expects(:apply_modifier)
          .with(:custom_homepage_enabled, false, request: nil, current_user: nil)
          .returns(true)
      end

      it "returns custom" do
        expect(HomepageHelper.resolve).to eq("custom")
      end
    end

    it "returns custom when a plugin modifies the custom_homepage_enabled to true" do
      DiscoursePluginRegistry
        .expects(:apply_modifier)
        .with(:custom_homepage_enabled, false, request: nil, current_user: nil)
        .returns(true)

      expect(HomepageHelper.resolve).to eq("custom")
    end

    context "when the configured homepage is not valid for anons" do
      before do
        SiteSetting.top_menu = "new|top|latest"
        SiteSetting.default_homepage = "new"
      end

      it "distinguishes between auth homepage and anon homepage" do
        expect(HomepageHelper.resolve(nil, user)).to eq("new")
        # new is not a valid route for anon users, so the anon homepage falls back
        # to the first anon-visible item in the top menu, top
        expect(HomepageHelper.resolve).to eq(SiteSetting.anonymous_homepage)
        expect(HomepageHelper.resolve).to eq("top")
      end
    end

    context "when default_homepage is set" do
      before { SiteSetting.top_menu = "latest|new|top|categories" }

      it "uses default_homepage regardless of top_menu order" do
        SiteSetting.default_homepage = "categories"
        expect(HomepageHelper.resolve(nil, user)).to eq("categories")
        expect(HomepageHelper.resolve).to eq("categories")
      end

      it "uses default_homepage even when it is not one of the top_menu items" do
        SiteSetting.top_menu = "latest|new|categories"
        SiteSetting.default_homepage = "top"
        expect(HomepageHelper.resolve(nil, user)).to eq("top")
        expect(HomepageHelper.resolve).to eq("top")
      end
    end

    context "when default_homepage is not set" do
      before { SiteSetting.top_menu = "new|top|latest" }

      it "falls back to the first top_menu item, and the first anon-visible one for anons" do
        expect(HomepageHelper.resolve(nil, user)).to eq("new")
        expect(HomepageHelper.resolve).to eq("top")
      end
    end

    context "with a registered homepage" do
      let(:plugin) { Plugin::Instance.new }

      around do |example|
        registrations = DiscoursePluginRegistry._raw_homepage_options.dup
        example.run
        DiscoursePluginRegistry._raw_homepage_options.replace(registrations)
      end

      before do
        plugin.stubs(:enabled?).returns(true)
        SiteSetting.top_menu = "new|top|latest"
      end

      it "falls back to the top menu when the homepage is unavailable" do
        plugin.register_homepage(
          "members_only",
          name: "plugin.members_only",
          path: "/members-only",
          route: "plugin#index",
          anonymous: true,
          available: ->(guardian:, request:) { !guardian.anonymous? },
        )
        SiteSetting.default_homepage = "members_only"

        expect(HomepageHelper.resolve(nil, user)).to eq("members_only")
        expect(HomepageHelper.resolve).to eq("top")
      end

      it "checks availability once per request and user" do
        calls = 0
        plugin.register_homepage(
          "counted",
          name: "plugin.counted",
          path: "/counted",
          route: "plugin#index",
          available: ->(guardian:, request:) do
            calls += 1
            true
          end,
        )
        SiteSetting.default_homepage = "counted"
        request = ActionDispatch::TestRequest.create

        3.times { HomepageHelper.resolve(request, user) }
        expect(calls).to eq(1)

        HomepageHelper.resolve(request, Fabricate(:user))
        expect(calls).to eq(2)
      end

      it "falls back to the top menu when the availability check raises" do
        plugin.register_homepage(
          "broken",
          name: "plugin.broken",
          path: "/broken",
          route: "plugin#index",
          available: ->(guardian:, request:) { raise "availability check failed" },
        )
        SiteSetting.default_homepage = "broken"

        expect(HomepageHelper.resolve(nil, user)).to eq("new")
      end

      it "passes the request to the availability check" do
        crawler_request = ActionDispatch::TestRequest.create("HTTP_USER_AGENT" => "Googlebot")
        plugin.register_homepage(
          "humans_only",
          name: "plugin.humans_only",
          path: "/humans-only",
          route: "plugin#index",
          available: ->(guardian:, request:) { !CrawlerDetection.crawler_layout_request?(request) },
        )
        SiteSetting.default_homepage = "humans_only"

        expect(HomepageHelper.resolve(nil, user)).to eq("humans_only")
        expect(HomepageHelper.resolve(crawler_request, user)).to eq("new")
      end
    end

    context "with login required" do
      before do
        SiteSetting.login_required = true
        SiteSetting.top_menu = "new|top|latest"
        SiteSetting.default_homepage = "new"
      end

      it "returns a blank route for anon, and the configured homepage for an authenticated user" do
        expect(HomepageHelper.resolve).to eq("blank")
        expect(HomepageHelper.resolve(nil, user)).to eq("new")
      end
    end
  end
end
