# frozen_string_literal: true

RSpec.describe DiscoursePoll::Poll do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:user_2, :user)
  fab!(:user_3, :user)

  fab!(:post_with_regular_poll) { Fabricate(:post, raw: <<~RAW) }
      [poll]
      * 1
      * 2
      [/poll]
    RAW

  fab!(:post_with_multiple_poll) { Fabricate(:post, raw: <<~RAW) }
      [poll type=multiple min=2 max=3]
      * 1
      * 2
      * 3
      * 4
      * 5
      [/poll]
    RAW

  fab!(:post_with_ranked_choice_poll) { Fabricate(:post, raw: <<~RAW) }
    [poll type=ranked_choice public=true]
    * Red
    * Blue
    * Yellow
    [/poll]
    RAW

  describe ".vote" do
    it "should only allow one vote per user for a regular poll" do
      poll = post_with_regular_poll.polls.first

      expect do
        DiscoursePoll::Poll.vote(
          user,
          post_with_regular_poll.id,
          "poll",
          poll.poll_options.map(&:digest),
        )
      end.to raise_error(DiscoursePoll::Error, I18n.t("poll.one_vote_per_user"))
    end

    it "should not allow a ranked vote with all abstentions" do
      poll = post_with_ranked_choice_poll.polls.first
      poll_options = poll.poll_options

      expect do
        DiscoursePoll::Poll.vote(
          user,
          post_with_ranked_choice_poll.id,
          "poll",
          {
            "0": {
              digest: poll_options.first.digest,
              rank: "0",
            },
            "1": {
              digest: poll_options.second.digest,
              rank: "0",
            },
            "2": {
              digest: poll_options.third.digest,
              rank: "0",
            },
          },
        )
      end.to raise_error(
        DiscoursePoll::Error,
        I18n.t("poll.requires_that_at_least_one_option_is_ranked"),
      )
    end

    it "should clean up bad votes for a regular poll" do
      poll = post_with_regular_poll.polls.first

      PollVote.create!(poll: poll, poll_option: poll.poll_options.first, user: user)

      PollVote.create!(poll: poll, poll_option: poll.poll_options.last, user: user)

      DiscoursePoll::Poll.vote(
        user,
        post_with_regular_poll.id,
        "poll",
        [poll.poll_options.first.digest],
      )

      expect(PollVote.where(poll: poll, user: user).pluck(:poll_option_id)).to contain_exactly(
        poll.poll_options.first.id,
      )
    end

    it "allows user to vote on multiple options correctly for a multiple poll" do
      poll = post_with_multiple_poll.polls.first
      poll_options = poll.poll_options

      [poll_options.first, poll_options.second, poll_options.third].each do |poll_option|
        PollVote.create!(poll: poll, poll_option: poll_option, user: user)
      end

      DiscoursePoll::Poll.vote(
        user,
        post_with_multiple_poll.id,
        "poll",
        [poll_options.first.digest, poll_options.second.digest],
      )

      DiscoursePoll::Poll.vote(
        user_2,
        post_with_multiple_poll.id,
        "poll",
        [poll_options.third.digest, poll_options.fourth.digest],
      )

      expect(PollVote.where(poll: poll, user: user).pluck(:poll_option_id)).to contain_exactly(
        poll_options.first.id,
        poll_options.second.id,
      )

      expect(PollVote.where(poll: poll, user: user_2).pluck(:poll_option_id)).to contain_exactly(
        poll_options.third.id,
        poll_options.fourth.id,
      )
    end

    it "should respect the min/max votes per user for a multiple poll" do
      poll = post_with_multiple_poll.polls.first

      expect do
        DiscoursePoll::Poll.vote(
          user,
          post_with_multiple_poll.id,
          "poll",
          poll.poll_options.map(&:digest),
        )
      end.to raise_error(DiscoursePoll::Error, I18n.t("poll.max_vote_per_user", count: poll.max))

      expect do
        DiscoursePoll::Poll.vote(
          user,
          post_with_multiple_poll.id,
          "poll",
          [poll.poll_options.first.digest],
        )
      end.to raise_error(DiscoursePoll::Error, I18n.t("poll.min_vote_per_user", count: poll.min))
    end

    it "should allow user to vote on a multiple poll even if min option is not configured" do
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
        [poll.poll_options.first.digest],
      )

      expect(PollVote.where(poll: poll, user: user).pluck(:poll_option_id)).to contain_exactly(
        poll.poll_options.first.id,
      )
    end

    it "should allow user to vote on a multiple poll even if max option is not configured" do
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
        [poll.poll_options.first.digest, poll.poll_options.second.digest],
      )

      expect(PollVote.where(poll: poll, user: user).pluck(:poll_option_id)).to contain_exactly(
        poll.poll_options.first.id,
        poll.poll_options.second.id,
      )
    end

    it "allows user to vote on options correctly for a ranked choice poll and to vote again" do
      poll = post_with_ranked_choice_poll.polls.first
      poll_options = poll.poll_options

      DiscoursePoll::Poll.vote(
        user,
        post_with_ranked_choice_poll.id,
        "poll",
        {
          "0": {
            digest: poll_options.first.digest,
            rank: "2",
          },
          "1": {
            digest: poll_options.second.digest,
            rank: "1",
          },
          "2": {
            digest: poll_options.third.digest,
            rank: "0",
          },
        },
      )

      DiscoursePoll::Poll.vote(
        user_2,
        post_with_ranked_choice_poll.id,
        "poll",
        {
          "0": {
            digest: poll_options.first.digest,
            rank: "0",
          },
          "1": {
            digest: poll_options.second.digest,
            rank: "2",
          },
          "2": {
            digest: poll_options.third.digest,
            rank: "1",
          },
        },
      )

      DiscoursePoll::Poll.vote(
        user,
        post_with_ranked_choice_poll.id,
        "poll",
        {
          "0": {
            digest: poll_options.first.digest,
            rank: "1",
          },
          "1": {
            digest: poll_options.second.digest,
            rank: "2",
          },
          "2": {
            digest: poll_options.third.digest,
            rank: "0",
          },
        },
      )

      expect(PollVote.count).to eq(6)

      expect(PollVote.where(poll: poll, user: user).pluck(:poll_option_id)).to contain_exactly(
        poll_options.first.id,
        poll_options.second.id,
        poll_options.third.id,
      )

      expect(PollVote.where(poll: poll, user: user_2).pluck(:poll_option_id)).to contain_exactly(
        poll_options.first.id,
        poll_options.second.id,
        poll_options.third.id,
      )
    end
  end

  describe "post_created" do
    it "publishes on message bus if a there are polls" do
      first_post = Fabricate(:post)
      topic = first_post.topic
      creator = PostCreator.new(user, topic_id: topic.id, raw: <<~RAW)
          [poll]
          * 1
          * 2
          [/poll]
        RAW

      messages = MessageBus.track_publish("/polls/#{topic.id}") { creator.create! }

      expect(messages.count).to eq(1)
    end

    it "does not publish on message bus when a post with no polls is created" do
      first_post = Fabricate(:post)
      topic = first_post.topic
      creator =
        PostCreator.new(user, topic_id: topic.id, raw: "Just a post with definitely no polls")

      messages = MessageBus.track_publish("/polls/#{topic.id}") { creator.create! }

      expect(messages.count).to eq(0)
    end
  end

  describe ".extract" do
    it "skips the polls inside quote" do
      raw = <<~RAW
      [quote="username, post:1, topic:2"]
        [poll type=regular result=always]
        * 1
        * 2
        [/poll]
      [/quote]

      [poll type=regular result=always]
      * 3
      * 4
      [/poll]

      Post with a poll and a quoted poll.
      RAW

      expect(DiscoursePoll::Poll.extract(raw, 2)).to contain_exactly(
        {
          "name" => "poll",
          "options" => [
            { "html" => "3", "id" => "68b434ff88aeae7054e42cd05a4d9056" },
            { "html" => "4", "id" => "aa2393b424f2f395abb63bf785760a3b" },
          ],
          "status" => "open",
          "type" => "regular",
        },
      )
    end
  end

  describe ".serialized_voters" do
    shared_examples "serialized_voters tests" do
      before do
        votes.each_pair { |user, options| DiscoursePoll::Poll.vote(user, post.id, "poll", options) }
      end

      it "returns all serialized voters" do
        voters = DiscoursePoll::Poll.serialized_voters(poll)
        if poll.ranked_choice?
          voters&.transform_values! do |users|
            users.sort_by { |ranked_u| ranked_u[:user][:username] }
          end
        end

        expect(voters).to eq(expected_voters)
      end

      it "correctly paginates voters" do
        page = 1
        loop do
          expected = expected_paginated_voters[page - 1]
          opts = { page:, limit: 2 }.with_indifferent_access

          voters = DiscoursePoll::Poll.serialized_voters(poll, opts)
          if poll.ranked_choice?
            voters&.transform_values! do |users|
              users.sort_by { |ranked_u| ranked_u[:user][:username] }
            end
          end

          expect(voters).to eq(expected)

          break unless voters
          page += 1
        end
      end
    end

    context "with a regular poll" do
      let(:post) { post_with_regular_poll }
      let(:poll) { post.polls.first }
      let(:poll_options) { poll.poll_options }

      let(:votes) do
        {
          user => [poll_options.first.digest],
          user_2 => [poll_options.second.digest],
          user_3 => [poll_options.first.digest],
        }
      end

      let(:expected_voters) do
        {
          poll_options.first.digest => [
            UserNameSerializer.new(user).serializable_hash,
            UserNameSerializer.new(user_3).serializable_hash,
          ],
          poll_options.second.digest => [UserNameSerializer.new(user_2).serializable_hash],
        }
      end
      let(:expected_paginated_voters) { [expected_voters] }

      include_examples "serialized_voters tests"
    end

    context "with a multi-choice poll" do
      let(:post) { post_with_multiple_poll }
      let(:poll) { post.polls.first }
      let(:poll_options) { poll.poll_options }

      let(:votes) do
        {
          user => [poll_options.first.digest, poll_options.second.digest],
          user_2 => [poll_options.second.digest, poll_options.third.digest],
          user_3 => [
            poll_options.second.digest,
            poll_options.third.digest,
            poll_options.fourth.digest,
          ],
        }
      end

      let(:expected_voters) do
        {
          poll_options.first.digest => [UserNameSerializer.new(user).serializable_hash],
          poll_options.second.digest => [
            UserNameSerializer.new(user).serializable_hash,
            UserNameSerializer.new(user_2).serializable_hash,
            UserNameSerializer.new(user_3).serializable_hash,
          ],
          poll_options.third.digest => [
            UserNameSerializer.new(user_2).serializable_hash,
            UserNameSerializer.new(user_3).serializable_hash,
          ],
          poll_options.fourth.digest => [UserNameSerializer.new(user_3).serializable_hash],
        }
      end
      let(:expected_paginated_voters) do
        [
          {
            poll_options.first.digest => [UserNameSerializer.new(user).serializable_hash],
            poll_options.second.digest => [
              UserNameSerializer.new(user).serializable_hash,
              UserNameSerializer.new(user_2).serializable_hash,
            ],
            poll_options.third.digest => [
              UserNameSerializer.new(user_2).serializable_hash,
              UserNameSerializer.new(user_3).serializable_hash,
            ],
            poll_options.fourth.digest => [UserNameSerializer.new(user_3).serializable_hash],
          },
          { poll_options.second.digest => [UserNameSerializer.new(user_3).serializable_hash] },
        ]
      end

      include_examples "serialized_voters tests"
    end

    context "with a ranked choice poll" do
      let(:post) { post_with_ranked_choice_poll }
      let(:poll) { post.polls.first }
      let(:poll_options) { poll.poll_options }

      let(:votes) do
        {
          user => {
            "0": {
              digest: poll_options.first.digest,
              rank: "0",
            },
            "1": {
              digest: poll_options.second.digest,
              rank: "1",
            },
            "2": {
              digest: poll_options.third.digest,
              rank: "2",
            },
          },
          user_2 => {
            "0": {
              digest: poll_options.second.digest,
              rank: "0",
            },
            "1": {
              digest: poll_options.third.digest,
              rank: "1",
            },
            "2": {
              digest: poll_options.first.digest,
              rank: "2",
            },
          },
          user_3 => {
            "0": {
              digest: poll_options.third.digest,
              rank: "0",
            },
            "1": {
              digest: poll_options.first.digest,
              rank: "1",
            },
            "2": {
              digest: poll_options.second.digest,
              rank: "2",
            },
          },
        }
      end

      let(:expected_voters) do
        {
          poll_options.first.digest => [
            { user: UserNameSerializer.new(user).serializable_hash, rank: "Abstain" },
            { user: UserNameSerializer.new(user_2).serializable_hash, rank: "2" },
            { user: UserNameSerializer.new(user_3).serializable_hash, rank: "1" },
          ],
          poll_options.second.digest => [
            { user: UserNameSerializer.new(user).serializable_hash, rank: "1" },
            { user: UserNameSerializer.new(user_2).serializable_hash, rank: "Abstain" },
            { user: UserNameSerializer.new(user_3).serializable_hash, rank: "2" },
          ],
          poll_options.third.digest => [
            { user: UserNameSerializer.new(user).serializable_hash, rank: "2" },
            { user: UserNameSerializer.new(user_2).serializable_hash, rank: "1" },
            { user: UserNameSerializer.new(user_3).serializable_hash, rank: "Abstain" },
          ],
        }
      end
      let(:expected_paginated_voters) do
        [
          {
            poll_options.first.digest => [
              { user: UserNameSerializer.new(user).serializable_hash, rank: "Abstain" },
              { user: UserNameSerializer.new(user_2).serializable_hash, rank: "2" },
            ],
            poll_options.second.digest => [
              { user: UserNameSerializer.new(user).serializable_hash, rank: "1" },
              { user: UserNameSerializer.new(user_2).serializable_hash, rank: "Abstain" },
            ],
            poll_options.third.digest => [
              { user: UserNameSerializer.new(user).serializable_hash, rank: "2" },
              { user: UserNameSerializer.new(user_2).serializable_hash, rank: "1" },
            ],
          },
          {
            poll_options.first.digest => [
              { user: UserNameSerializer.new(user_3).serializable_hash, rank: "1" },
            ],
            poll_options.second.digest => [
              { user: UserNameSerializer.new(user_3).serializable_hash, rank: "2" },
            ],
            poll_options.third.digest => [
              { user: UserNameSerializer.new(user_3).serializable_hash, rank: "Abstain" },
            ],
          },
        ]
      end

      include_examples "serialized_voters tests"
    end
  end
end
