require 'rails_helper'

describe DiscoursePoll::PollsUpdater do
  let(:user) { Fabricate(:user) }

  let(:post_with_two_polls) do
    raw = <<-RAW.strip_heredoc
    [poll]
    * 1
    * 2
    [/poll]

    [poll name=test]
    * 1
    * 2
    [/poll]
    RAW

    Fabricate(:post, raw: raw)
  end

  let(:post) do
    raw = <<-RAW.strip_heredoc
    [poll]
    * 1
    * 2
    [/poll]
    RAW

    Fabricate(:post, raw: raw)
  end

  let(:other_post) do
    raw = <<-RAW.strip_heredoc
    [poll]
    * 3
    * 4
    * 5
    [/poll]
    RAW

    Fabricate(:post, raw: raw)
  end

  let(:polls) do
    DiscoursePoll::PollsValidator.new(post).validate_polls
  end

  let(:polls_with_3_options) do
    DiscoursePoll::PollsValidator.new(other_post).validate_polls
  end

  let(:two_polls) do
    DiscoursePoll::PollsValidator.new(post_with_two_polls).validate_polls
  end

  describe '.update' do
    describe 'when post does not contain any polls' do
      it 'should update polls correctly' do
        post = Fabricate(:post)

        message = MessageBus.track_publish do
          described_class.update(post, polls)
        end.first

        expect(post.reload.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD]).to eq(polls)
        expect(message.data[:post_id]).to eq(post.id)
        expect(message.data[:polls]).to eq(polls)
      end
    end

    describe 'when post contains existing polls' do
      it "should be able to update polls correctly" do
        message = MessageBus.track_publish do
          described_class.update(post, polls_with_3_options)
        end.first

        expect(post.reload.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD]).to eq(polls_with_3_options)
        expect(message.data[:post_id]).to eq(post.id)
        expect(message.data[:polls]).to eq(polls_with_3_options)
      end
    end

    describe 'when there are no changes' do
      it "should not do anything" do
        messages = MessageBus.track_publish do
          described_class.update(post, polls)
        end

        expect(messages).to eq([])
      end
    end

    context "public polls" do
      let(:post) do
        raw = <<-RAW.strip_heredoc
        [poll public=true]
        - A
        - B
        [/poll]
        RAW

        Fabricate(:post, raw: raw)
      end

      let(:private_poll_post) do
        raw = <<-RAW.strip_heredoc
        [poll]
        - A
        - B
        [/poll]
        RAW

        Fabricate(:post, raw: raw)
      end

      let(:private_poll) do
        DiscoursePoll::PollsValidator.new(private_poll_post).validate_polls
      end

      let(:public_poll) do
        raw = <<-RAW.strip_heredoc
        [poll public=true]
        - A
        - C
        [/poll]
        RAW

        DiscoursePoll::PollsValidator.new(Fabricate(:post, raw: raw)).validate_polls
      end

      before do
        DiscoursePoll::Poll.vote(post.id, "poll", ["5c24fc1df56d764b550ceae1b9319125"], user)
        post.reload
      end

      it "should not allow a private poll with votes to be made public" do
        DiscoursePoll::Poll.vote(private_poll_post.id, "poll", ["5c24fc1df56d764b550ceae1b9319125"], user)
        private_poll_post.reload

        messages = MessageBus.track_publish do
          described_class.update(private_poll_post, public_poll)
        end

        expect(messages).to eq([])

        expect(private_poll_post.errors[:base]).to include(
          I18n.t("poll.default_cannot_be_made_public")
        )
      end

      it "should retain voter_ids when options have been edited" do
        described_class.update(post, public_poll)

        polls = post.reload.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD]

        expect(polls["poll"]["options"][0]["voter_ids"]).to eq([user.id])
        expect(polls["poll"]["options"][1]["voter_ids"]).to eq([])
      end

      it "should delete voter_ids when poll is set to private" do
        described_class.update(post, private_poll)

        polls = post.reload.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD]

        expect(post.reload.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD])
          .to eq(private_poll)

        expect(polls["poll"]["options"][0]["voter_ids"]).to eq(nil)
        expect(polls["poll"]["options"][1]["voter_ids"]).to eq(nil)
      end
    end

    context "polls of type 'multiple'" do
      let(:min_2_post) do
        raw = <<-RAW.strip_heredoc
        [poll type=multiple min=2 max=3]
        - Option 1
        - Option 2
        - Option 3
        [/poll]
        RAW

        Fabricate(:post, raw: raw)
      end

      let(:min_2_poll) do
        DiscoursePoll::PollsValidator.new(min_2_post).validate_polls
      end

      let(:min_1_post) do
        raw = <<-RAW.strip_heredoc
        [poll type=multiple min=1 max=2]
        - Option 1
        - Option 2
        - Option 3
        [/poll]
        RAW

        Fabricate(:post, raw: raw)
      end

      let(:min_1_poll) do
        DiscoursePoll::PollsValidator.new(min_1_post).validate_polls
      end

      it "should be able to update options" do
        min_2_poll

        message = MessageBus.track_publish do
          described_class.update(min_2_post, min_1_poll)
        end.first

        expect(min_2_post.reload.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD]).to eq(min_1_poll)
        expect(message.data[:post_id]).to eq(min_2_post.id)
        expect(message.data[:polls]).to eq(min_1_poll)
      end
    end

    it 'should be able to edit multiple polls with votes' do
      DiscoursePoll::Poll.vote(
        post_with_two_polls.id,
        "poll",
        [two_polls["poll"]["options"].first["id"]],
        user
      )

      raw = <<-RAW.strip_heredoc
      [poll]
      * 12
      * 34
      [/poll]

      [poll name=test]
      * 12
      * 34
      [/poll]
      RAW

      different_post = Fabricate(:post, raw: raw)
      different_polls = DiscoursePoll::PollsValidator.new(different_post).validate_polls

      message = MessageBus.track_publish do
        described_class.update(post_with_two_polls.reload, different_polls)
      end.first

      expect(post_with_two_polls.reload.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD])
        .to eq(different_polls)

      expect(message.data[:post_id]).to eq(post_with_two_polls.id)
      expect(message.data[:polls]).to eq(different_polls)
    end

    describe "when poll edit window has expired" do
      let(:poll_edit_window_mins) { 6 }
      let(:another_post) { Fabricate(:post, created_at: Time.zone.now - poll_edit_window_mins.minutes) }

      before do
        described_class.update(another_post, polls)
        another_post.reload
        SiteSetting.poll_edit_window_mins = poll_edit_window_mins

        DiscoursePoll::Poll.vote(
          another_post.id,
          "poll",
          [polls["poll"]["options"].first["id"]],
          user
        )
      end

      it "should not allow users to edit options of current poll" do
        messages = MessageBus.track_publish do
          described_class.update(another_post, polls_with_3_options)
        end

        expect(another_post.errors[:base]).to include(I18n.t(
          "poll.edit_window_expired.op_cannot_edit_options",
          minutes: poll_edit_window_mins
        ))

        expect(messages).to eq([])
      end

      context "staff" do
        let(:another_user) { Fabricate(:user) }

        before do
          another_post.update_attributes!(last_editor_id: User.staff.first.id)
        end

        it "should allow staff to add polls" do
          message = MessageBus.track_publish do
            described_class.update(another_post, two_polls)
          end.first

          expect(another_post.errors.full_messages).to eq([])

          expect(message.data[:post_id]).to eq(another_post.id)
          expect(message.data[:polls]).to eq(two_polls)
        end

        it "should not allow staff to add options if votes have been casted" do
          another_post.update_attributes!(last_editor_id: User.staff.first.id)

          messages = MessageBus.track_publish do
            described_class.update(another_post, polls_with_3_options)
          end

          expect(another_post.errors[:base]).to include(I18n.t(
            "poll.edit_window_expired.staff_cannot_add_or_remove_options",
            minutes: poll_edit_window_mins
          ))

          expect(messages).to eq([])
        end

        it "should allow staff to add options if no votes have been casted" do
          post.update_attributes!(
            created_at: Time.zone.now - 5.minutes,
            last_editor_id: User.staff.first.id
          )

          message = MessageBus.track_publish do
            described_class.update(post, polls_with_3_options)
          end.first

          expect(post.reload.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD]).to eq(polls_with_3_options)
          expect(message.data[:post_id]).to eq(post.id)
          expect(message.data[:polls]).to eq(polls_with_3_options)
        end

        it "should allow staff to edit options even if votes have been casted" do
          another_post.update!(last_editor_id: User.staff.first.id)

          DiscoursePoll::Poll.vote(
            another_post.id,
            "poll",
            [polls["poll"]["options"].first["id"]],
            another_user
          )

          raw = <<-RAW.strip_heredoc
          [poll]
          * 3
          * 4
          [/poll]
          RAW

          different_post = Fabricate(:post, raw: raw)
          different_polls = DiscoursePoll::PollsValidator.new(different_post).validate_polls

          message = MessageBus.track_publish do
            described_class.update(another_post, different_polls)
          end.first

          custom_fields = another_post.reload.custom_fields

          expect(custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD])
            .to eq(different_polls)

          [user, another_user].each do |u|
            expect(custom_fields[DiscoursePoll::VOTES_CUSTOM_FIELD][u.id.to_s]["poll"])
              .to eq(["68b434ff88aeae7054e42cd05a4d9056"])
          end

          expect(message.data[:post_id]).to eq(another_post.id)
          expect(message.data[:polls]).to eq(different_polls)
        end

        it "should allow staff to edit options if votes have not been casted" do
          post.update_attributes!(last_editor_id: User.staff.first.id)

          raw = <<-RAW.strip_heredoc
          [poll]
          * 3
          * 4
          [/poll]
          RAW

          different_post = Fabricate(:post, raw: raw)
          different_polls = DiscoursePoll::PollsValidator.new(different_post).validate_polls

          message = MessageBus.track_publish do
            described_class.update(post, different_polls)
          end.first

          expect(post.reload.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD]).to eq(different_polls)
          expect(message.data[:post_id]).to eq(post.id)
          expect(message.data[:polls]).to eq(different_polls)
        end
      end
    end
  end

  describe '.extract_option_ids' do
    it 'should return an array of the options id' do
      expect(described_class.extract_option_ids(polls)).to eq(
        ["4d8a15e3cc35750f016ce15a43937620", "cd314db7dfbac2b10687b6f39abfdf41"]
      )
    end
  end

  describe '.total_votes' do
    let!(:post) do
      raw = <<-RAW.strip_heredoc
      [poll]
      * 1
      * 2
      [/poll]

      [poll name=test]
      * 1
      * 2
      [/poll]
      RAW

      Fabricate(:post, raw: raw)
    end

    it "should return the right number of votes" do
      expect(described_class.total_votes(polls)).to eq(0)

      polls.each { |key, value| value["voters"] = 2 }

      expect(described_class.total_votes(polls)).to eq(4)
    end
  end
end
