# frozen_string_literal: true

require 'rails_helper'

describe EmojiSerializer do
  fab!(:emoji) do
    CustomEmoji.create!(name: 'trout', upload: Fabricate(:upload))
    Emoji.load_custom.first
  end

  subject { described_class.new(emoji, root: false) }

  describe '#url' do
    it 'returns a valid URL' do
      expect(subject.url).to start_with('/uploads/')
    end

    it 'works with a CDN' do
      set_cdn_url('https://cdn.com')
      expect(subject.url).to start_with('https://cdn.com')
    end
  end
end
