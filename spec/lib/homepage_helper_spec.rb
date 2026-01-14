# frozen_string_literal: true

RSpec.describe HomepageHelper do
  describe "resolver" do
    fab!(:user)

    it "returns latest by default" do
      expect(HomepageHelper.resolve).to eq("latest")
    end

    context "when theme has a custom homepage" do
      before { ThemeModifierHelper.any_instance.expects(:custom_homepage).returns(true) }

      it "returns custom" do
        expect(HomepageHelper.resolve).to eq("custom")
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

    context "when first item in top menu is not valid for anons" do
      before { SiteSetting.top_menu = "new|top|latest|unread" }

      it "distinguishes between auth homepage and anon homepage" do
        expect(HomepageHelper.resolve(nil, user)).to eq("new")
        # new is not a valid route for anon users, anon homepage is next item, top
        expect(HomepageHelper.resolve).to eq(SiteSetting.anonymous_homepage)
        expect(HomepageHelper.resolve).to eq("top")
      end
    end

    context "with login required" do
      before do
        SiteSetting.login_required = true
        SiteSetting.top_menu = "new|top|latest|unread"
      end

      it "returns a blank route for anon, first result from top menu for authenticated user" do
        expect(HomepageHelper.resolve).to eq("blank")
        expect(HomepageHelper.resolve(nil, user)).to eq("new")
      end
    end
  end
end
