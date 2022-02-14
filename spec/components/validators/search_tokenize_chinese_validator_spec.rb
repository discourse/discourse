# frozen_string_literal: true

require 'rails_helper'

describe SearchTokenizeChineseValidator do
  it 'does not allow search_tokenize_chinese to be enabled when search_tokenize_japanese is enabled' do
    SiteSetting.search_tokenize_japanese = true

    expect { SiteSetting.search_tokenize_chinese = true }.to raise_error(Discourse::InvalidParameters)
  end
end
