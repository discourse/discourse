# frozen_string_literal: true
RSpec.describe Chat::ChatableUserSerializer do
  fab!(:user) { Fabricate(:user) }
  subject(:serializer) { described_class.new(user, scope: Guardian.new(user), root: false) }

  it "serializes a user" do
    json = serializer.as_json

    expect(json).to eq(
      {
        id: user.id,
        username: user.username,
        name: user.name,
        avatar_template: user.avatar_template,
        custom_fields: {
        },
        can_chat: false,
        has_chat_enabled: false,
      },
    )
  end
end
