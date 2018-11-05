# frozen_string_literal: true
require 'rails_helper'

RSpec.describe JavascriptCache, type: :model do
  let(:theme) { Fabricate(:theme) }
  let(:theme_field) { ThemeField.create!(theme: theme, target_id: 0, name: "header", value: "<a>html</a>") }

  describe '#save' do
    it 'updates the digest only if the content has changed' do
      javascript_cache = JavascriptCache.create!(content: 'console.log("hello");', theme_field: theme_field)
      expect(javascript_cache.digest).to_not be_empty

      expect { javascript_cache.save! }.to_not change { javascript_cache.reload.digest }

      expect do
        javascript_cache.content = 'console.log("world");'
        javascript_cache.save!
      end.to change { javascript_cache.reload.digest }
    end

    it 'allows content to be empty, but not nil' do
      javascript_cache = JavascriptCache.create!(content: 'console.log("hello");', theme_field: theme_field)

      javascript_cache.content = ''
      expect(javascript_cache.valid?).to eq(true)

      javascript_cache.content = nil
      expect(javascript_cache.valid?).to eq(false)
      expect(javascript_cache.errors.details[:content]).to include(error: :empty)
    end
  end

  describe 'url' do
    it 'works with multisite' do
      javascript_cache = JavascriptCache.create!(content: 'console.log("hello");', theme_field: theme_field)
      expect(javascript_cache.url).to include("?__ws=test.localhost")
    end
  end
end
