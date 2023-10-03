# frozen_string_literal: true

RSpec.describe Chat::UserChatThreadMembership do
  it { is_expected.to belong_to(:user).class_name("User") }
  it { is_expected.to belong_to(:last_read_message).class_name("Chat::Message") }
  it { is_expected.to belong_to(:thread).class_name("Chat::Thread") }

  it do
    is_expected.to define_enum_for(:notification_level).with_values(
      muted: 0,
      normal: 1,
      tracking: 2,
      watching: 3,
    )
  end
end
