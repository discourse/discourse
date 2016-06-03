require 'rails_helper'

describe DiscoursePoll::PollsUpdater do
  let(:post_with_two_polls) do
    raw = <<~RAW
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
    raw = <<~RAW
    [poll]
    * 1
    * 2
    [/poll]
    RAW

    Fabricate(:post, raw: raw)
  end

  let(:other_post) do
    raw = <<~RAW
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

  let(:new_polls) do
    DiscoursePoll::PollsValidator.new(other_post).validate_polls
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
          described_class.update(post, new_polls)
        end.first

        expect(post.reload.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD]).to eq(new_polls)
        expect(message.data[:post_id]).to eq(post.id)
        expect(message.data[:polls]).to eq(new_polls)
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

    describe "when post has been created more than 5 minutes ago" do
      let(:another_post) { Fabricate(:post, created_at: Time.zone.now - 10.minutes) }

      let(:more_polls) do
        DiscoursePoll::PollsValidator.new(post_with_two_polls).validate_polls
      end

      before do
        polls.each { |key, value| value["voters"] = 2 }
        described_class.update(another_post, polls)
      end

      it "should not allow new polls to be added" do
        messages = MessageBus.track_publish do
          described_class.update(another_post, more_polls)
        end

        expect(another_post.errors[:base]).to include(I18n.t(
          "poll.cannot_change_polls_after_5_minutes")
        )

        expect(messages).to eq([])
      end

      it "should not allow users to edit options of current" do
        messages = MessageBus.track_publish do
          described_class.update(another_post, new_polls)
        end

        expect(another_post.errors[:base]).to include(I18n.t(
          "poll.op_cannot_edit_options_after_5_minutes"
        ))

        expect(messages).to eq([])
      end

      context "staff" do
        it "should not allow staff to add options if votes have been casted" do
          another_post.update_attributes!(last_editor_id: User.staff.first.id)

          messages = MessageBus.track_publish do
            described_class.update(another_post, new_polls)
          end

          expect(another_post.errors[:base]).to include(I18n.t(
            "poll.staff_cannot_add_or_remove_options_after_5_minutes"
          ))

          expect(messages).to eq([])
        end

        it "should allow staff to add options if no votes have been casted" do
          post.update_attributes!(
            created_at: Time.zone.now - 10.minutes,
            last_editor_id: User.staff.first.id
          )

          message = MessageBus.track_publish do
            described_class.update(post, new_polls)
          end.first

          expect(post.reload.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD]).to eq(new_polls)
          expect(message.data[:post_id]).to eq(post.id)
          expect(message.data[:polls]).to eq(new_polls)
        end

        it "should allow staff to edit options if votes have been casted" do
          another_post.update_attributes!(last_editor_id: User.staff.first.id)

          raw = <<~RAW
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

          different_polls.each { |key, value| value["voters"] = 2 }

          expect(another_post.reload.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD]).to eq(different_polls)
          expect(message.data[:post_id]).to eq(another_post.id)
          expect(message.data[:polls]).to eq(different_polls)
        end

        it "should allow staff to edit options if votes have not been casted" do
          post.update_attributes!(last_editor_id: User.staff.first.id)

          raw = <<~RAW
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
      raw = <<~RAW
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
