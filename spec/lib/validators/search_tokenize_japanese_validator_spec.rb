# frozen_string_literal: true

require 'rails_helper'

describe SearchTokenizeJapaneseValidator do
  it 'does not allow search_tokenize_japanese to be enabled when search_tokenize_chinese is enabled' do
    SiteSetting.search_tokenize_chinese = true

    expect { SiteSetting.search_tokenize_japanese = true }.to raise_error(Discourse::InvalidParameters)
  end
end
