# frozen_string_literal: true

describe Chat::Statistics do
  fab!(:frozen_time) { DateTime.parse("2022-07-08 09:30:00") }

  def minus_time(time)
    frozen_time - time
  end

  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }
  fab!(:user3) { Fabricate(:user) }
  fab!(:user4) { Fabricate(:user) }
  fab!(:user5) { Fabricate(:user) }

  fab!(:channel1) { Fabricate(:chat_channel, created_at: minus_time(1.hour)) }
  fab!(:channel2) { Fabricate(:chat_channel, created_at: minus_time(2.days)) }
  fab!(:channel3) { Fabricate(:chat_channel, created_at: minus_time(6.days)) }
  fab!(:channel3) { Fabricate(:chat_channel, created_at: minus_time(20.days)) }
  fab!(:channel4) { Fabricate(:chat_channel, created_at: minus_time(21.days), status: :closed) }
  fab!(:channel5) { Fabricate(:chat_channel, created_at: minus_time(24.days)) }
  fab!(:channel6) { Fabricate(:chat_channel, created_at: minus_time(40.days)) }
  fab!(:channel7) { Fabricate(:chat_channel, created_at: minus_time(100.days), status: :archived) }

  fab!(:membership1) do
    Fabricate(:user_chat_channel_membership, user: user1, chat_channel: channel1)
  end
  fab!(:membership2) do
    Fabricate(:user_chat_channel_membership, user: user2, chat_channel: channel1)
  end
  fab!(:membership3) do
    Fabricate(:user_chat_channel_membership, user: user3, chat_channel: channel1)
  end

  fab!(:message1) do
    Fabricate(:chat_message, chat_channel: channel1, created_at: minus_time(5.minutes), user: user1)
  end
  fab!(:message2) do
    Fabricate(:chat_message, chat_channel: channel1, created_at: minus_time(2.days), user: user2)
  end
  fab!(:message3) do
    Fabricate(:chat_message, chat_channel: channel1, created_at: minus_time(6.days), user: user2)
  end
  fab!(:message4) do
    Fabricate(:chat_message, chat_channel: channel1, created_at: minus_time(11.days), user: user2)
  end
  fab!(:message5) do
    Fabricate(:chat_message, chat_channel: channel4, created_at: minus_time(12.days), user: user3)
  end
  fab!(:message6) do
    Fabricate(:chat_message, chat_channel: channel1, created_at: minus_time(13.days), user: user2)
  end
  fab!(:message7) do
    Fabricate(:chat_message, chat_channel: channel1, created_at: minus_time(16.days), user: user1)
  end
  fab!(:message8) do
    Fabricate(:chat_message, chat_channel: channel1, created_at: minus_time(42.days), user: user3)
  end
  fab!(:message9) do
    Fabricate(
      :chat_message,
      chat_channel: channel1,
      created_at: minus_time(42.days),
      user: user3,
      deleted_at: minus_time(10.days),
      deleted_by: user3,
    )
  end
  fab!(:message10) do
    Fabricate(:chat_message, chat_channel: channel1, created_at: minus_time(50.days), user: user4)
  end
  fab!(:message10) do
    Fabricate(:chat_message, chat_channel: channel1, created_at: minus_time(62.days), user: user4)
  end

  before { freeze_time(DateTime.parse("2022-07-08 09:30:00")) }

  describe "#about_messages" do
    it "counts non-deleted messages created in all status channels in the time period accurately" do
      about_messages = described_class.about_messages
      expect(about_messages[:last_day]).to eq(1)
      expect(about_messages["7_days"]).to eq(3)
      expect(about_messages["30_days"]).to eq(7)
      expect(about_messages[:previous_30_days]).to eq(2)
      expect(about_messages[:count]).to eq(10)
    end
  end

  describe "#about_channels" do
    it "counts open channels created in the time period accurately" do
      about_channels = described_class.about_channels
      expect(about_channels[:last_day]).to eq(1)
      expect(about_channels["7_days"]).to eq(3)
      expect(about_channels["30_days"]).to eq(5)
      expect(about_channels[:previous_30_days]).to eq(1)
      expect(about_channels[:count]).to eq(6)
    end
  end

  describe "#about_users" do
    it "counts any users who have sent any message to a chat channel in the time periods accurately" do
      about_users = described_class.about_users
      expect(about_users[:last_day]).to eq(1)
      expect(about_users["7_days"]).to eq(2)
      expect(about_users["30_days"]).to eq(3)
      expect(about_users[:previous_30_days]).to eq(2)
      expect(about_users[:count]).to eq(4)
    end
  end

  describe "#monthly" do
    it "has the correct counts of users, messages, and channels created since the start of this month" do
      monthly = described_class.monthly
      expect(monthly[:messages]).to eq(3)
      expect(monthly[:channels]).to eq(3)
      expect(monthly[:users]).to eq(2)
    end
  end
end
