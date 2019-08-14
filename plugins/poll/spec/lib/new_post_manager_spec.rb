# frozen_string_literal: true

require "rails_helper"

describe NewPostManager do
  let(:user) { Fabricate(:newuser) }
  let(:admin) { Fabricate(:admin) }

  describe "when new post containing a poll is queued for approval" do
    before do
      SiteSetting.poll_minimum_trust_level_to_create = 0
    end

    let(:params) do
      {
        raw: "[poll]\n* 1\n* 2\n* 3\n[/poll]",
        archetype: "regular",
        category: "",
        typing_duration_msecs: "2700",
        composer_open_duration_msecs: "12556",
        visible: true,
        image_sizes: nil,
        is_warning: false,
        title: "This is a test post with a poll",
        ip_address: "127.0.0.1",
        user_agent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/55.0.2883.87 Safari/537.36",
        referrer: "http://localhost:3000/",
        first_post_checks: true
      }
    end

    it "should render the poll upon approval" do
      result = NewPostManager.new(user, params).perform
      expect(result.action).to eq(:enqueued)
      expect(result.reviewable).to be_present

      review_result = result.reviewable.perform(admin, :approve_post)
      expect(Poll.where(post: review_result.created_post).exists?).to eq(true)
    end

    it 're-validates the poll when the approve_post event is triggered' do
      invalid_raw_poll = <<~RAW
        [poll type=multiple min=0]
        * 1
        * 2
        [/poll]
      RAW

      result = NewPostManager.new(user, params).perform

      reviewable = result.reviewable
      reviewable.payload["raw"] = invalid_raw_poll
      reviewable.save!

      review_result = result.reviewable.perform(admin, :approve_post)
      expect(Poll.where(post: review_result.created_post).exists?).to eq(false)
    end
  end
end
