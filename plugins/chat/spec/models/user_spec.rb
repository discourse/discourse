# frozen_string_literal: true

RSpec.describe User do
  it { is_expected.to have_many(:user_chat_channel_memberships).dependent(:destroy) }
  it { is_expected.to have_many(:chat_message_reactions).dependent(:destroy) }
  it { is_expected.to have_many(:chat_mentions) }
end
