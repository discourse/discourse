# frozen_string_literal: true

RSpec.describe TopicViewDetailsSerializer do
  describe "#allowed_users" do
    it "add the current user to the allowed user's list even if they are an allowed group member" do
      participant = Fabricate(:user)
      another_participant = Fabricate(:user)

      participant_group = Fabricate(:group)
      participant_group.add(participant)
      participant_group.add(another_participant)

      pm =
        Fabricate(
          :private_message_topic,
          topic_allowed_users: [
            Fabricate.build(:topic_allowed_user, user: participant),
            Fabricate.build(:topic_allowed_user, user: another_participant),
          ],
          topic_allowed_groups: [Fabricate.build(:topic_allowed_group, group: participant_group)],
        )

      serializer =
        described_class.new(TopicView.new(pm, participant), scope: Guardian.new(participant))
      allowed_users = serializer.as_json.dig(:topic_view_details, :allowed_users).map { |u| u[:id] }

      expect(allowed_users).to contain_exactly(participant.id)
    end
  end

  describe "#can_permanently_delete" do
    let(:post) do
      Fabricate(:post).tap do |post|
        PostDestroyer.new(Discourse.system_user, post, context: "Automated testing").destroy
      end
    end

    before { SiteSetting.can_permanently_delete = true }

    it "is true for admins" do
      admin = Fabricate(:admin)

      serializer = described_class.new(TopicView.new(post.topic, admin), scope: Guardian.new(admin))
      expect(serializer.as_json.dig(:topic_view_details, :can_permanently_delete)).to eq(true)
    end

    it "is not present for moderators" do
      moderator = Fabricate(:moderator)

      serializer =
        described_class.new(TopicView.new(post.topic, moderator), scope: Guardian.new(moderator))
      expect(serializer.as_json.dig(:topic_view_details, :can_permanently_delete)).to eq(nil)
    end
  end

  describe "#can_delete" do
    before { SiteSetting.enable_category_group_moderation = true }

    it "is true for category moderators in their category" do
      user = Fabricate(:user, trust_level: TrustLevel[4])
      Group.user_trust_level_change!(user.id, user.trust_level)
      category = Fabricate(:category)
      topic = Fabricate(:topic, category:)
      Fabricate(:category_moderation_group, category:, group: user.groups.first)

      serializer = described_class.new(TopicView.new(topic, user), scope: Guardian.new(user))
      expect(serializer.as_json.dig(:topic_view_details, :can_delete)).to eq(true)
    end

    it "is false for regular users" do
      user = Fabricate(:user)
      topic = Fabricate(:topic)

      serializer = described_class.new(TopicView.new(topic, user), scope: Guardian.new(user))
      expect(serializer.as_json.dig(:topic_view_details, :can_delete)).to eq(nil)
    end
  end
end
