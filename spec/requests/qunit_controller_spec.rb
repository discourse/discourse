# frozen_string_literal: true

require 'rails_helper'

describe QunitController do
  let(:theme) { Fabricate(:theme, name: 'main-theme') }
  let(:component) { Fabricate(:theme, component: true, name: 'enabled-component') }
  let(:disabled_component) { Fabricate(:theme, component: true, enabled: false, name: 'disabled-component') }

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

  context "when no theme is specified" do
    it "includes tests of enabled theme + components" do
      get '/qunit'
      js_urls = JavascriptCache.where(theme_id: [theme.id, component.id]).map(&:url)
      expect(js_urls.size).to eq(2)
      js_urls.each do |url|
        expect(response.body).to include(url)
      end
      [theme, component].each do |t|
        expect(response.body).to include("/theme-javascripts/tests/#{t.id}.js")
      end

      js_urls = JavascriptCache.where(theme_id: disabled_component).map(&:url)
      expect(js_urls.size).to eq(1)
      js_urls.each do |url|
        expect(response.body).not_to include(url)
      end
      expect(response.body).not_to include("/theme-javascripts/tests/#{disabled_component.id}.js")
    end
  end

  context "when a theme is specified" do
    it "includes tests of the specified theme only" do
      [theme, disabled_component].each do |t|
        get "/qunit?theme_name=#{t.name}"
        js_urls = JavascriptCache.where(theme_id: t.id).map(&:url)
        expect(js_urls.size).to eq(1)
        js_urls.each do |url|
          expect(response.body).to include(url)
        end
        expect(response.body).to include("/theme-javascripts/tests/#{t.id}.js")

        excluded = Theme.pluck(:id) - [t.id]
        js_urls = JavascriptCache.where(theme_id: excluded).map(&:url)
        expect(js_urls.size).to eq(2)
        js_urls.each do |url|
          expect(response.body).not_to include(url)
        end
        excluded.each do |id|
          expect(response.body).not_to include("/theme-javascripts/tests/#{id}.js")
        end
      end
    end
  end
end
