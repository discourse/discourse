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
  end
end
