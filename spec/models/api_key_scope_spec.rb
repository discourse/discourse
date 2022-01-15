# frozen_string_literal: true

require 'rails_helper'

describe ApiKeyScope do
  describe '.find_urls' do
    it 'should return the right urls' do
      expect(ApiKeyScope.find_urls(actions: ["posts#create"], methods: []))
        .to contain_exactly("/posts (POST)")
    end
  end
end
