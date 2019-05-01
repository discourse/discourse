# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::RebakeCustomEmojiPosts do
  it 'should rebake posts that are using a given custom emoji' do
    upload = Fabricate(:upload)
    custom_emoji = CustomEmoji.create!(name: 'test', upload: upload)
    Emoji.clear_cache
    post = Fabricate(:post, raw: 'some post with :test: yay')

    expect(post.reload.cooked).to eq(
      "<p>some post with <img src=\"#{upload.url}?v=#{Emoji::EMOJI_VERSION}\" title=\":test:\" class=\"emoji emoji-custom\" alt=\":test:\"> yay</p>"
    )

    custom_emoji.destroy!
    Emoji.clear_cache
    described_class.new.execute(name: 'test')

    expect(post.reload.cooked).to eq('<p>some post with :test: yay</p>')
  end
end
