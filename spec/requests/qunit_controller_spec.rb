# frozen_string_literal: true

require 'rails_helper'

describe QunitController do
  describe "#theme" do
    let(:theme) { Fabricate(:theme, name: 'main-theme') }
    let(:component) { Fabricate(:theme, component: true, name: 'enabled-component') }
    let(:disabled_component) { Fabricate(:theme, component: true, enabled: false, name: 'disabled-component') }
    let(:theme_without_tests) { Fabricate(:theme, name: 'no-tests-guy') }

    before do
      Theme.destroy_all
      theme.set_default!
      component.add_relative_theme!(:parent, theme)
      disabled_component.add_relative_theme!(:parent, theme)
      [theme, component, disabled_component].each do |t|
        t.set_field(
          target: :extra_js,
          type: :js,
          name: "discourse/initializers/my-#{t.id}-initializer.js",
          value: "console.log(#{t.id});"
        )
        t.set_field(
          target: :tests_js,
          type: :js,
          name: "acceptance/some-test-#{t.id}.js",
          value: "assert.ok(#{t.id});"
        )
        t.save!
      end
    end

    context "non-admin users on production" do
      before do
        # We need to call sign_in before stubbing the method because SessionController#become
        # checks for the current env when the file is loaded.
        # We need to make sure become is called once before stubbing, or the method
        # wont'be available for future tests if this one runs first.
        sign_in(Fabricate(:user))
        Rails.env.stubs(:production?).returns(true)
      end

      it "regular users cannot see the page" do
        get '/theme-qunit'
        expect(response.status).to eq(404)
      end

      it "anons cannot see the page" do
        sign_out
        get '/theme-qunit'
        expect(response.status).to eq(404)
      end
    end

    context "admin users" do
      before do
        sign_in(Fabricate(:admin))
      end

      context "when no theme is specified" do
        it "renders a list of themes and components that have tests" do
          get '/theme-qunit'
          expect(response.status).to eq(200)
          [theme, component, disabled_component].each do |t|
            expect(response.body).to include(t.name)
            expect(response.body).to include("/theme-qunit?id=#{t.id}")
          end
          expect(response.body).not_to include(theme_without_tests.name)
          expect(response.body).not_to include("/theme-qunit?id=#{theme_without_tests.id}")
        end
      end

      it "can specify theme by id" do
        get "/theme-qunit?id=#{theme.id}"
        expect(response.status).to eq(200)
        expect(response.body).to include("/theme-javascripts/tests/#{theme.id}-")
      end

      it "can specify theme by name" do
        get "/theme-qunit?name=#{theme.name}"
        expect(response.status).to eq(200)
        expect(response.body).to include("/theme-javascripts/tests/#{theme.id}-")
      end

      it "can specify theme by url" do
        theme.build_remote_theme(remote_url: "git@github.com:discourse/discourse.git").save!
        theme.save!
        get "/theme-qunit?url=#{theme.remote_theme.remote_url}"
        expect(response.status).to eq(200)
        expect(response.body).to include("/theme-javascripts/tests/#{theme.id}-")
      end

      it "themes qunit page includes all the JS/CSS it needs" do
        get "/theme-qunit?id=#{theme.id}"
        expect(response.status).to eq(200)
        expect(response.body).to include("/stylesheets/color_definitions_base_")
        expect(response.body).to include("/stylesheets/desktop_")
        expect(response.body).to include("/stylesheets/test_helper_")
        expect(response.body).to include("/assets/locales/en.js")
        expect(response.body).to include("/test-support")
        expect(response.body).to include("/test-helpers")
        expect(response.body).to include("/assets/markdown-it-bundle.js")
        expect(response.body).to include("/assets/application.js")
        expect(response.body).to include("/assets/admin.js")
        expect(response.body).to match(/\/theme-javascripts\/\h{40}\.js/)
        expect(response.body).to include("/theme-javascripts/tests/#{theme.id}-")
      end
    end
  end
end
