# frozen_string_literal: true

RSpec.describe DiscourseEvents::Livestream::ChatTranscriptAudience do
  subject(:audience) { described_class.new(event, channel:) }

  fab!(:members, :group)
  fab!(:guests, :group)
  fab!(:category)

  let(:event) do
    Fabricate(
      :event,
      post: Fabricate(:post, topic: Fabricate(:topic, category:)),
      status: DiscourseEvents::Events::Event.statuses[event_status],
      raw_invitees: invited_groups.map(&:name),
    )
  end
  let(:channel) { Fabricate(:category_channel, chatable: category) }
  let(:event_status) { :public }
  let(:invited_groups) { [] }

  before { SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_1].to_s }

  describe "#matches_topic_readers?" do
    context "when anonymous users can read the topic" do
      it { is_expected.not_to be_matches_topic_readers }

      context "when anonymous users can read public chat channels too" do
        before do
          SiteSetting.chat_allowed_groups =
            Group::AUTO_GROUPS.values_at(:anonymous_users, :trust_level_0).join("|")
        end

        it { is_expected.to be_matches_topic_readers }

        it "does not match when public channels are disabled" do
          SiteSetting.enable_public_channels = false

          expect(audience).not_to be_matches_topic_readers
        end

        context "when the event is invite-only" do
          let(:event_status) { :private }
          let(:invited_groups) { [members] }

          it { is_expected.not_to be_matches_topic_readers }
        end
      end
    end

    context "when the site requires login" do
      before { SiteSetting.login_required = true }

      it "does not match while new users cannot chat" do
        expect(audience).not_to be_matches_topic_readers
      end

      it "matches once every logged in user can chat" do
        SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_0].to_s

        expect(audience).to be_matches_topic_readers
      end
    end

    context "when the category is restricted to groups that can chat" do
      before do
        category.set_permissions(members => :full)
        category.save!
        SiteSetting.chat_allowed_groups = members.id.to_s
      end

      it { is_expected.to be_matches_topic_readers }

      context "when the topic has moved away from the channel's category" do
        let(:channel) do
          Fabricate(:category_channel, chatable: Fabricate(:private_category, group: guests))
        end

        it { is_expected.not_to be_matches_topic_readers }
      end

      context "when the event is invite-only" do
        let(:event_status) { :private }

        context "when every reader group is invited" do
          let(:invited_groups) { [members] }

          it { is_expected.to be_matches_topic_readers }
        end

        context "when some reader groups are not invited" do
          let(:invited_groups) { [guests] }

          it { is_expected.not_to be_matches_topic_readers }
        end
      end
    end

    context "when the category is restricted to a group that cannot chat" do
      before do
        category.set_permissions(guests => :readonly)
        category.save!
      end

      it { is_expected.not_to be_matches_topic_readers }
    end

    context "when the category is restricted by trust level" do
      before do
        category.set_permissions(Group::AUTO_GROUPS[:trust_level_2] => :full)
        category.save!
      end

      it "matches when a lower trust level can chat" do
        expect(audience).to be_matches_topic_readers
      end
    end
  end
end
