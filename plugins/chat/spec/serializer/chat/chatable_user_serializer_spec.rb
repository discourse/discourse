# frozen_string_literal: true
RSpec.describe Chat::ChatableUserSerializer do
  fab!(:user)
  subject(:serializer) { described_class.new(user, scope: Guardian.new(user), root: false) }

  before do
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:everyone]
  end

  it "serializes a user" do
    expect(serializer.as_json).to eq(
      {
        id: user.id,
        username: user.username,
        name: user.name,
        avatar_template: user.avatar_template,
        custom_fields: {
        },
        can_chat: true,
        has_chat_enabled: true,
      },
    )
  end

  context "when chat is disabled" do
    before { SiteSetting.chat_enabled = false }

    it "can't chat" do
      expect(serializer.as_json[:can_chat]).to eq(false)
    end
  end

  context "when user is not allowed to chat" do
    before { SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_4] }

    it "can't chat" do
      expect(serializer.as_json[:can_chat]).to eq(false)
    end
  end

  context "when user has chat disabled" do
    before { user.user_option.update!(chat_enabled: false) }

    it "has chat disabled" do
      expect(serializer.as_json[:has_chat_enabled]).to eq(false)
    end
  end

  context "when user can't use direct messages" do
    before { SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_4] }

    it "can't chat" do
      expect(serializer.as_json[:can_chat]).to eq(false)
    end
  end

  context "when staff creates direct messages" do
    fab!(:admin)
    subject(:serializer) { described_class.new(user, scope: Guardian.new(admin), root: false) }

    before { SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:trust_level_4] }

    it "can chat" do
      expect(serializer.as_json[:can_chat]).to eq(true)
    end

    it "can't chat if user has chat disabled" do
      user.user_option.update!(chat_enabled: false)
      expect(serializer.as_json[:has_chat_enabled]).to eq(false)
    end
  end
end
