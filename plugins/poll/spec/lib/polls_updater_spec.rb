require 'rails_helper'

describe DiscoursePoll::PollsUpdater do

  def update(post, polls)
    DiscoursePoll::PollsUpdater.update(post, polls)
  end

  let(:user) { Fabricate(:user) }

  let(:post) {
    Fabricate(:post, raw: <<~RAW)
      [poll]
      * 1
      * 2
      [/poll]
    RAW
  }

  let(:post_with_3_options) {
    Fabricate(:post, raw: <<~RAW)
      [poll]
      - a
      - b
      - c
      [/poll]
    RAW
  }

  let(:post_with_some_attributes) {
    Fabricate(:post, raw: <<~RAW)
      [poll close=#{1.week.from_now.to_formatted_s(:iso8601)} results=on_close]
      - A
      - B
      - C
      [/poll]
    RAW
  }

  let(:polls) {
    DiscoursePoll::PollsValidator.new(post).validate_polls
  }

  let(:polls_with_3_options) {
    DiscoursePoll::PollsValidator.new(post_with_3_options).validate_polls
  }

  let(:polls_with_some_attributes) {
    DiscoursePoll::PollsValidator.new(post_with_some_attributes).validate_polls
  }

  describe "update" do

    it "does nothing when there are no changes" do
      message = MessageBus.track_publish do
        update(post, polls)
      end.first

      expect(message).to be(nil)
    end

    describe "when editing" do

      let(:raw) do
        <<~RAW
        This is a new poll with three options.

        [poll type=multiple results=always min=1 max=2]
        * first
        * second
        * third
        [/poll]
        RAW
      end

      let(:post) { Fabricate(:post, raw: raw) }

      it "works if poll is closed and unmodified" do
        DiscoursePoll::Poll.vote(post.id, "poll", ["e55de753c08b93d04d677ce05e942d3c"], post.user)
        DiscoursePoll::Poll.toggle_status(post.id, "poll", "closed", post.user)

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

        message = MessageBus.track_publish do
          update(post, polls)
        end.first

        poll = Poll.find_by(post: post)

        expect(poll).to be
        expect(poll.poll_options.size).to eq(2)

        expect(poll.post.custom_fields[DiscoursePoll::HAS_POLLS]).to eq(true)

        expect(message.data[:post_id]).to eq(post.id)
        expect(message.data[:polls][0][:name]).to eq(poll.name)
      end

    end

    describe "updates polls" do

      describe "when there are no votes" do

        it "at any time" do
          post # create the post

          freeze_time 1.month.from_now

          message = MessageBus.track_publish do
            update(post, polls_with_some_attributes)
          end.first

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
            DiscoursePoll::Poll.vote(post.id, "poll", [polls["poll"]["options"][0]["id"]], user)
          }.to change { PollVote.count }.by(1)
        end

        describe "inside the edit window" do

          it "and deletes the votes" do
            message = MessageBus.track_publish do
              update(post, polls_with_some_attributes)
            end.first

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
                minutes: edit_window
              )
            )
          end

        end

      end

    end

  end

end
