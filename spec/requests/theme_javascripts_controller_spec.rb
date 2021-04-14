# frozen_string_literal: true
require 'rails_helper'

describe ThemeJavascriptsController do
  let!(:theme) { Fabricate(:theme) }
  let(:theme_field) { ThemeField.create!(theme: theme, target_id: 0, name: "header", value: "<a>html</a>") }
  let(:javascript_cache) { JavascriptCache.create!(content: 'console.log("hello");', theme_field: theme_field) }

  describe '#show' do
    def update_digest_and_get(digest)
      # actually set digest to make sure 404 is raised by router
      javascript_cache.update(digest: digest)

      get "/theme-javascripts/#{digest}.js"
    end

    it 'only accepts 40-char hexdecimal digest name' do
      update_digest_and_get('0123456789abcdefabcd0123456789abcdefabcd')
      expect(response.status).to eq(200)

      update_digest_and_get('0123456789abcdefabcd0123456789abcdefabc')
      expect(response.status).to eq(404)

      update_digest_and_get('gggggggggggggggggggggggggggggggggggggggg')
      expect(response.status).to eq(404)

      update_digest_and_get('0123456789abcdefabc_0123456789abcdefabcd')
      expect(response.status).to eq(404)

      update_digest_and_get('0123456789abcdefabc-0123456789abcdefabcd')
      expect(response.status).to eq(404)

      update_digest_and_get('../../Gemfile')
      expect(response.status).to eq(404)
    end

    it 'considers the database record as the source of truth' do
      clear_disk_cache

      get "/theme-javascripts/#{javascript_cache.digest}.js"
      expect(response.status).to eq(200)
      expect(response.body).to eq(javascript_cache.content)
      expect(response.headers['Content-Length']).to eq(javascript_cache.content.bytesize.to_s)

      javascript_cache.destroy!

      get "/theme-javascripts/#{javascript_cache.digest}.js"
      expect(response.status).to eq(404)
    end

    def clear_disk_cache
      if Dir.exist?(ThemeJavascriptsController::DISK_CACHE_PATH)
        `rm #{ThemeJavascriptsController::DISK_CACHE_PATH}/*`
      end
    end
  end

  describe "#show_tests" do
    context "theme settings" do
      let(:component) { Fabricate(:theme, component: true, name: 'enabled-component') }

      it "forces default values" do
        ThemeField.create!(
          theme: component,
          target_id: Theme.targets[:settings],
          name: "yaml",
          value: "num_setting: 5"
        )
        component.reload
        component.update_setting(:num_setting, 643)

        get "/theme-javascripts/tests/#{component.id}.js"
        expect(response.body).to include("require(\"discourse/lib/theme-settings-store\").registerSettings(#{component.id}, {\"num_setting\":5}, { force: true });")
      end
    end
  end
end
