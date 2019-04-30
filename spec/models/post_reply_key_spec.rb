# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PostReplyKey do
  describe "#reply_key" do
    it "should format the reply_key correctly" do
      hex = SecureRandom.hex
      post_reply_key = Fabricate(:post_reply_key,
        reply_key: hex
      )

      raw_key = PostReplyKey.where(id: post_reply_key.id)
        .pluck("reply_key::text")
        .first

      expect(raw_key).to_not eq(hex)
      expect(raw_key.delete('-')).to eq(hex)
      expect(PostReplyKey.find(post_reply_key.id).reply_key).to eq(hex)
    end
  end
end
