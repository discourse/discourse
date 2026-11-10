# frozen_string_literal: true

RSpec.describe DiscourseNarrativeBot::PostGuardianExtension do
  fab!(:user)
  fab!(:moderator)
  fab!(:discobot_user) { DiscourseNarrativeBot::Base.new.discobot_user }
  fab!(:topic) { Fabricate(:system_message_topic, user: discobot_user, recipient: user) }

  before do
    SiteSetting.discourse_narrative_bot_enabled = true
    SiteSetting.enable_system_message_replies = false
  end

  describe "#can_create_post?" do
    it "allows participants to reply even when system message replies are disabled" do
      expect(user.guardian.can_create_post?(topic)).to eq(true)
    end

    it "allows members of an allowed group to reply" do
      group = Fabricate(:group)
      group.add(moderator)
      topic.topic_allowed_groups.create!(group: group)

      expect(moderator.guardian.can_create_post?(topic)).to eq(true)
    end

    it "denies replies from non-participant moderators" do
      expect(moderator.guardian.can_create_post?(topic)).to eq(false)
    end
  end
end
