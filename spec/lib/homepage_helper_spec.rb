# frozen_string_literal: true

RSpec.describe HomepageHelper do
  describe "resolver" do
    fab!(:user)

    it "returns latest by default" do
      expect(HomepageHelper.resolve).to eq("latest")
    end

    it "returns custom when theme has a custom homepage" do
      ThemeModifierHelper.any_instance.expects(:custom_homepage).returns(true)

      expect(HomepageHelper.resolve).to eq("custom")
    end

    context "when first item in top menu is not valid for anons" do
      it "distinguishes between auth homepage and anon homepage" do
        SiteSetting.top_menu = "new|top|latest|unread"

        expect(HomepageHelper.resolve(nil, user)).to eq("new")
        # new is not a valid route for anon users, anon homepage is next item, top
        expect(HomepageHelper.resolve).to eq(SiteSetting.anonymous_homepage)
        expect(HomepageHelper.resolve).to eq("top")
      end
    end
  end
end
