# frozen_string_literal: true

RSpec.describe QunitController do
  def production_sign_in(user)
    # We need to call sign_in before stubbing the method because SessionController#become
    # checks for the current env when the file is loaded.
    # We need to make sure become is called once before stubbing, or the method
    # wont'be available for future tests if this one runs first.
    sign_in(user) if user
    Rails.env.stubs(:production?).returns(true)
  end

  describe "#index" do
    it "hides page for regular users in production" do
      production_sign_in(Fabricate(:user))
      get "/theme-qunit"
      expect(response.status).to eq(404)
    end

    it "hides page for anon in production" do
      production_sign_in(nil)
      get "/theme-qunit"
      expect(response.status).to eq(404)
    end

    it "shows page for admin in production" do
      production_sign_in(Fabricate(:admin))
      get "/theme-qunit"
      expect(response.status).to eq(200)
    end

    it "lists only themes that have tests" do
      theme_with_tests = Fabricate(:theme, name: "Theme With Tests")
      theme_with_tests.set_field(
        target: :tests_js,
        type: :js,
        name: "acceptance/some-test.js",
        value: "// noop",
      )
      theme_with_tests.save!
      theme_without_tests = Fabricate(:theme, name: "no-tests-guy")

      get "/theme-qunit"

      expect(response.status).to eq(200)
      expect(response.body).to include(%(href="/theme-qunit?id=#{theme_with_tests.id}"))
      expect(response.body).not_to include(%(href="/theme-qunit?id=#{theme_without_tests.id}"))
    end
  end

  describe "#theme" do
    fab!(:theme) do
      theme = Fabricate(:theme, name: "Theme With Tests")
      theme.set_field(
        target: :tests_js,
        type: :js,
        name: "acceptance/some-test.js",
        value: "// noop",
      )
      theme.build_remote_theme(remote_url: "https://example.com/mytheme")
      theme.save!
      theme
    end

    before { EmberAssets.stubs(:has_tests?).returns(false) }

    it "resolves the theme by id" do
      get "/theme-qunit", params: { id: theme.id }
      expect(response.status).to eq(200)
      expect(response.body).to include("Discourse QUnit Test Runner")
    end

    it "resolves the theme by name" do
      get "/theme-qunit", params: { name: theme.name }
      expect(response.status).to eq(200)
      expect(response.body).to include("Discourse QUnit Test Runner")
    end

    it "resolves the theme by remote url" do
      get "/theme-qunit", params: { url: theme.remote_theme.remote_url }
      expect(response.status).to eq(200)
      expect(response.body).to include("Discourse QUnit Test Runner")
    end

    it "returns a 404 when no theme matches" do
      get "/theme-qunit", params: { id: 99_999_999 }
      expect(response.status).to eq(404)
    end
  end
end
