# frozen_string_literal: true

require 'rails_helper'

describe ::DiscoursePoll::Poll do
  describe ".transform_for_user_field_override" do
    it "Transforms UserField name if a matching CustomUserField is present" do
      user_field_name = "Something Cool"
      user_field = Fabricate(:user_field, name: user_field_name)
      expect(::DiscoursePoll::Poll.transform_for_user_field_override(user_field_name)).to eq("user_field_#{user_field.id}")
    end

    it "does not transform UserField name if a matching CustomUserField is not present" do
      user_field_name = "Something Cool"
      user_field = Fabricate(:user_field, name: "Something Else!")
      expect(::DiscoursePoll::Poll.transform_for_user_field_override(user_field_name)).to eq(user_field_name)
    end
  end

  describe "can see results?" do
    it "everyone can see results when results setting is always" do
      post = Fabricate(:post, raw: "[poll]\n- A\n- B\n[/poll]")
      user = Fabricate(:user)
      expect(post.polls.first.can_see_results?(user)).to eq(true)
    end

    it "users who voted can see results when results setting is on_vote" do
      post = Fabricate(:post, raw: "[poll results=on_vote]\n- A\n- B\n[/poll]")
      user = Fabricate(:user)
      poll = post.polls.first
      option = poll.poll_options.first

      expect(poll.can_see_results?(user)).to eq(false)
      poll.poll_votes.create!(poll_option_id: option.id , user_id: user.id)
      expect(poll.can_see_results?(user)).to eq(true)
    end

    it "everyone can see results when results setting is on_vote and poll is closed" do
      post = Fabricate(:post, raw: "[poll results=on_vote]\n- A\n- B\n[/poll]")
      user = Fabricate(:user)
      poll = post.polls.first

      expect(poll.can_see_results?(user)).to eq(false)
      poll.update(close_at: Date.yesterday)
      expect(poll.can_see_results?(user)).to eq(true)
    end

    it "only staff memebers can see results when results setting is staff_only" do
      post = Fabricate(:post, raw: "[poll results=staff_only]\n- A\n- B\n[/poll]")
      user = Fabricate(:user)
      poll = post.polls.first
      option = poll.poll_options.first

      expect(poll.can_see_results?(user)).to eq(false)
      poll.poll_votes.create!(poll_option_id: option.id , user_id: user.id)
      expect(poll.can_see_results?(user)).to eq(false)
      user.update!(moderator: true)
      expect(poll.can_see_results?(user)).to eq(true)
    end
  end
end
