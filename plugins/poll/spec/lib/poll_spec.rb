# frozen_string_literal: true

require 'rails_helper'

describe DiscoursePoll::Poll do
  fab!(:user) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }

  fab!(:post_with_regular_poll) do
    Fabricate(:post, raw: <<~RAW)
      [poll]
      * 1
      * 2
      [/poll]
    RAW
  end

  fab!(:post_with_multiple_poll) do
    Fabricate(:post, raw: <<~RAW)
      [poll type=multiple min=2 max=3]
      * 1
      * 2
      * 3
      * 4
      * 5
      [/poll]
    RAW
  end

  describe '.vote' do
    it 'should only allow one vote per user for a regular poll' do
      poll = post_with_regular_poll.polls.first

      expect do
        DiscoursePoll::Poll.vote(
          user,
          post_with_regular_poll.id,
          "poll",
          poll.poll_options.map(&:digest)
        )
      end.to raise_error(DiscoursePoll::Error, I18n.t("poll.one_vote_per_user"))
    end

    it 'should clean up bad votes for a regular poll' do
      poll = post_with_regular_poll.polls.first

      PollVote.create!(
        poll: poll,
        poll_option: poll.poll_options.first,
        user: user
      )

      PollVote.create!(
        poll: poll,
        poll_option: poll.poll_options.last,
        user: user
      )

      DiscoursePoll::Poll.vote(
        user,
        post_with_regular_poll.id,
        "poll",
        [poll.poll_options.first.digest]
      )

      expect(PollVote.where(poll: poll, user: user).pluck(:poll_option_id))
        .to contain_exactly(poll.poll_options.first.id)
    end

    it 'allows user to vote on multiple options correctly for a multiple poll' do
      poll = post_with_multiple_poll.polls.first
      poll_options = poll.poll_options

      [
        poll_options.first,
        poll_options.second,
        poll_options.third,
      ].each do |poll_option|
        PollVote.create!(poll: poll, poll_option: poll_option, user: user)
      end

      DiscoursePoll::Poll.vote(
        user,
        post_with_multiple_poll.id,
        "poll",
        [poll_options.first.digest, poll_options.second.digest]
      )

      DiscoursePoll::Poll.vote(
        user_2,
        post_with_multiple_poll.id,
        "poll",
        [poll_options.third.digest, poll_options.fourth.digest]
      )

      expect(PollVote.where(poll: poll, user: user).pluck(:poll_option_id))
        .to contain_exactly(poll_options.first.id, poll_options.second.id)

      expect(PollVote.where(poll: poll, user: user_2).pluck(:poll_option_id))
        .to contain_exactly(poll_options.third.id, poll_options.fourth.id)
    end

    it 'should respect the min/max votes per user for a multiple poll' do
      poll = post_with_multiple_poll.polls.first

      expect do
        DiscoursePoll::Poll.vote(
          user,
          post_with_multiple_poll.id,
          "poll",
          poll.poll_options.map(&:digest)
        )
      end.to raise_error(
        DiscoursePoll::Error,
        I18n.t("poll.max_vote_per_user", count: poll.max)
      )

      expect do
        DiscoursePoll::Poll.vote(
          user,
          post_with_multiple_poll.id,
          "poll",
          [poll.poll_options.first.digest]
        )
      end.to raise_error(
        DiscoursePoll::Error,
        I18n.t("poll.min_vote_per_user", count: poll.min)
      )
    end

    it 'should allow user to vote on a multiple poll even if min option is not configured' do
      post_with_multiple_poll = Fabricate(:post, raw: <<~RAW)
      [poll type=multiple max=3]
      * 1
      * 2
      * 3
      * 4
      * 5
      [/poll]
      RAW

      poll = post_with_multiple_poll.polls.first

      DiscoursePoll::Poll.vote(
        user,
        post_with_multiple_poll.id,
        "poll",
        [poll.poll_options.first.digest]
      )

      expect(PollVote.where(poll: poll, user: user).pluck(:poll_option_id))
        .to contain_exactly(poll.poll_options.first.id)
    end

    it 'should allow user to vote on a multiple poll even if max option is not configured' do
      post_with_multiple_poll = Fabricate(:post, raw: <<~RAW)
      [poll type=multiple min=1]
      * 1
      * 2
      * 3
      * 4
      * 5
      [/poll]
      RAW

      poll = post_with_multiple_poll.polls.first

      DiscoursePoll::Poll.vote(
        user,
        post_with_multiple_poll.id,
        "poll",
        [poll.poll_options.first.digest, poll.poll_options.second.digest]
      )

      expect(PollVote.where(poll: poll, user: user).pluck(:poll_option_id))
        .to contain_exactly(poll.poll_options.first.id, poll.poll_options.second.id)
    end
  end

  describe "post_created" do
    it "publishes on message bus if a there are polls" do
      first_post = Fabricate(:post)
      topic = first_post.topic
      creator = PostCreator.new(user,
        topic_id: topic.id,
        raw: <<~RAW
          [poll]
          * 1
          * 2
          [/poll]
        RAW
      )

      messages = MessageBus.track_publish("/polls/#{topic.id}") do
        creator.create!
      end

      expect(messages.count).to eq(1)
    end

    it "does not publish on message bus when a post with no polls is created" do
      first_post = Fabricate(:post)
      topic = first_post.topic
      creator = PostCreator.new(user,
        topic_id: topic.id,
        raw: "Just a post with definitely no polls"
      )

      messages = MessageBus.track_publish("/polls/#{topic.id}") do
        creator.create!
      end

      expect(messages.count).to eq(0)
    end
  end
end
