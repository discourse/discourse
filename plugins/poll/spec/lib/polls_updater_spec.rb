# frozen_string_literal: true

RSpec.describe DiscoursePoll::PollsUpdater do
  def update(post, polls)
    DiscoursePoll::PollsUpdater.update(post, polls)
  end

  let(:user) { Fabricate(:user) }

  let(:post) { Fabricate(:post, raw: <<~RAW) }
      [poll]
      * 1
      * 2
      [/poll]
    RAW

  let(:post_with_3_options) { Fabricate(:post, raw: <<~RAW) }
      [poll]
      - a
      - b
      - c
      [/poll]
    RAW

  let(:post_with_some_attributes) { Fabricate(:post, raw: <<~RAW) }
      [poll close=#{1.week.from_now.to_formatted_s(:iso8601)} results=on_close]
      - A
      - B
      - C
      [/poll]
    RAW

  let(:polls) { DiscoursePoll::PollsValidator.new(post).validate_polls }

  let(:polls_with_3_options) do
    DiscoursePoll::PollsValidator.new(post_with_3_options).validate_polls
  end

  let(:polls_with_some_attributes) do
    DiscoursePoll::PollsValidator.new(post_with_some_attributes).validate_polls
  end

  describe "update" do
    it "does nothing when there are no changes" do
      message = MessageBus.track_publish("/polls/#{post.topic_id}") { update(post, polls) }.first

      expect(message).to be(nil)
    end

    describe "when editing" do
      let(:raw) { <<~RAW }
        This is a new poll with three options.

        [poll type=multiple results=always min=1 max=2]
        * first
        * second
        * third
        [/poll]
        RAW

      let(:post) { Fabricate(:post, raw: raw) }

      it "works if poll is closed and unmodified" do
        DiscoursePoll::Poll.vote(post.user, post.id, "poll", ["e55de753c08b93d04d677ce05e942d3c"])
        DiscoursePoll::Poll.toggle_status(post.user, post.id, "poll", "closed")

        freeze_time (SiteSetting.poll_edit_window_mins + 1).minutes.from_now
        update(post, DiscoursePoll::PollsValidator.new(post).validate_polls)

        expect(post.errors[:base].size).to equal(0)
      end
    end

    describe "deletes polls" do
      it "that were removed" do
        update(post, {})

        post.reload

        expect(Poll.where(post: post).exists?).to eq(false)
        expect(post.custom_fields[DiscoursePoll::HAS_POLLS]).to eq(nil)
      end
    end

    describe "creates polls" do
      it "that were added" do
        post = Fabricate(:post)

        expect(Poll.find_by(post: post)).to_not be

        message = MessageBus.track_publish("/polls/#{post.topic_id}") { update(post, polls) }.first

        poll = Poll.find_by(post: post)

        expect(poll).to be
        expect(poll.poll_options.size).to eq(2)

        expect(poll.post.custom_fields[DiscoursePoll::HAS_POLLS]).to eq(true)

        expect(message.data[:post_id]).to eq(post.id)
        expect(message.data[:polls][0][:name]).to eq(poll.name)
      end
    end

    describe "updates polls" do
      it "allows updating options after window when dynamic" do
        post = Fabricate(:post, raw: <<~RAW)
        [poll dynamic=true]
        * A
        * B
        [/poll]
      RAW

        polls = DiscoursePoll::PollsValidator.new(post).validate_polls
        DiscoursePoll::PollsUpdater.update(post, polls)

        poll_record = Poll.find_by(post: post)
        # dynamic is not persisted in DB; behavior is allowed via flag in updater

        # cast a vote
        user = Fabricate(:user)
        DiscoursePoll::Poll.vote(user, post.id, "poll", [polls["poll"]["options"][0]["id"]])

        edit_window = SiteSetting.poll_edit_window_mins
        freeze_time (edit_window + 10).minutes.from_now

        new_post = Fabricate(:post, raw: <<~RAW)
        [poll dynamic=true]
        * A
        * C
        [/poll]
      RAW

        new_polls = DiscoursePoll::PollsValidator.new(new_post).validate_polls
        DiscoursePoll::PollsUpdater.update(post, new_polls)

        poll_record.reload
        digests = poll_record.poll_options.pluck(:digest)
        expect(digests.size).to eq(2)
        expect(poll_record.poll_votes.count).to eq(1)
      end
      describe "when there are no votes" do
        it "at any time" do
          post # create the post

          freeze_time 1.month.from_now

          message =
            MessageBus
              .track_publish("/polls/#{post.topic_id}") { update(post, polls_with_some_attributes) }
              .first

          poll = Poll.find_by(post: post)

          expect(poll).to be
          expect(poll.poll_options.size).to eq(3)
          expect(poll.poll_votes.size).to eq(0)
          expect(poll.on_close?).to eq(true)
          expect(poll.close_at).to be

          expect(poll.post.custom_fields[DiscoursePoll::HAS_POLLS]).to eq(true)

          expect(message.data[:post_id]).to eq(post.id)
          expect(message.data[:polls][0][:name]).to eq(poll.name)
        end
      end

      describe "when there are votes" do
        before do
          expect {
            DiscoursePoll::Poll.vote(user, post.id, "poll", [polls["poll"]["options"][0]["id"]])
          }.to change { PollVote.count }.by(1)
        end

        describe "inside the edit window" do
          it "and deletes the votes" do
            message =
              MessageBus
                .track_publish("/polls/#{post.topic_id}") do
                  update(post, polls_with_some_attributes)
                end
                .first

            poll = Poll.find_by(post: post)

            expect(poll).to be
            expect(poll.poll_options.size).to eq(3)
            expect(poll.poll_votes.size).to eq(0)
            expect(poll.on_close?).to eq(true)
            expect(poll.close_at).to be

            expect(poll.post.custom_fields[DiscoursePoll::HAS_POLLS]).to eq(true)

            expect(message.data[:post_id]).to eq(post.id)
            expect(message.data[:polls][0][:name]).to eq(poll.name)
          end
        end

        describe "outside the edit window" do
          it "throws an error" do
            edit_window = SiteSetting.poll_edit_window_mins

            freeze_time (edit_window + 1).minutes.from_now

            update(post, polls_with_some_attributes)

            poll = Poll.find_by(post: post)

            expect(poll).to be
            expect(poll.poll_options.size).to eq(2)
            expect(poll.poll_votes.size).to eq(1)
            expect(poll.on_close?).to eq(false)
            expect(poll.close_at).to_not be

            expect(post.errors[:base]).to include(
              I18n.t(
                "poll.edit_window_expired.cannot_edit_default_poll_with_votes",
                minutes: edit_window,
              ),
            )
          end
        end

        it "does not allow converting an existing poll to dynamic after creation" do
          # Create a regular poll
          post = Fabricate(:post, raw: <<~RAW)
          [poll]
          * A
          * B
          [/poll]
          RAW

          polls = DiscoursePoll::PollsValidator.new(post).validate_polls
          DiscoursePoll::PollsUpdater.update(post, polls)

          # cast a vote so updates would normally be blocked outside window
          voter = Fabricate(:user)
          DiscoursePoll::Poll.vote(voter, post.id, "poll", [polls["poll"]["options"][0]["id"]])

          # Advance time and attempt to convert to dynamic while changing options
          edit_window = SiteSetting.poll_edit_window_mins
          freeze_time (edit_window + 10).minutes.from_now

          new_post = Fabricate(:post, raw: <<~RAW)
          [poll dynamic=true]
          * A
          * C
          [/poll]
          RAW

          new_polls = DiscoursePoll::PollsValidator.new(new_post).validate_polls
          DiscoursePoll::PollsUpdater.update(post, new_polls)

          poll_record = Poll.find_by(post: post)
          digests = poll_record.poll_options.pluck(:digest)
          # Conversion should be ignored; options should remain unchanged
          expect(digests.size).to eq(2)
          expect(digests).to match_array(polls["poll"]["options"].map { |o| o["id"] })
          # Vote should still be present
          expect(poll_record.poll_votes.count).to eq(1)
        end
      end
    end

    context "when no polls" do
      it "does not attempt to update polls" do
        DiscoursePoll::PollsUpdater.stubs(:update).raises(StandardError)
        no_poll_post = Fabricate(:post)

        raw = <<~RAW
          no poll here, moving on
        RAW

        no_poll_post.raw = raw
        expect(no_poll_post.valid?).to eq(true)
      end

      it "does not need to validate post" do
        DiscoursePoll::PostValidator.stubs(:validate_post).raises(StandardError)
        no_poll_post =
          Post.new(user: user, topic: Fabricate(:topic), raw: "no poll here, meoving on")

        expect(no_poll_post.valid?).to eq(true)
      end
    end
  end
end
