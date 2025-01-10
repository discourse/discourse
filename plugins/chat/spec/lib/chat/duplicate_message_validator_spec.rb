# frozen_string_literal: true

describe Chat::DuplicateMessageValidator do
  let(:chat_channel) { Fabricate(:chat_channel) }

  def message_blocked?(message)
    chat_message = Fabricate.build(:chat_message, message: message, chat_channel: chat_channel)
    described_class.new(chat_message).validate
    chat_message.errors.full_messages.include?(I18n.t("chat.errors.duplicate_message"))
  end

  it "adds no errors when chat_duplicate_message_sensitivity is 0" do
    SiteSetting.chat_duplicate_message_sensitivity = 0
    expect(message_blocked?("test")).to eq(false)
  end

  skip "errors if the message meets the requirements for sensitivity 0.1" do
    SiteSetting.chat_duplicate_message_sensitivity = 0.1

    chat_channel.update!(user_count: 100)
    message = "this is a 30 char message for test"
    dupe =
      Fabricate(
        :chat_message,
        created_at: 1.second.ago,
        message: message,
        chat_channel: chat_channel,
      )
    expect(message_blocked?(message)).to eq(true)

    expect(message_blocked?("blah")).to eq(false)

    dupe.update!(created_at: 11.seconds.ago)
    expect(message_blocked?(message)).to eq(false)
  end

  skip "errors if the message meets the requirements for sensitivity 0.5" do
    SiteSetting.chat_duplicate_message_sensitivity = 0.5
    chat_channel.update!(user_count: 57)
    message = "this is a 21 char msg"
    dupe =
      Fabricate(
        :chat_message,
        created_at: 1.second.ago,
        message: message,
        chat_channel: chat_channel,
      )
    expect(message_blocked?(message)).to eq(true)

    expect(message_blocked?("blah")).to eq(false)

    dupe.update!(created_at: 33.seconds.ago)
    expect(message_blocked?(message)).to eq(false)
  end

  skip "errors if the message meets the requirements for sensitivity 1.0" do
    SiteSetting.chat_duplicate_message_sensitivity = 1.0
    chat_channel.update!(user_count: 5)
    message = "10 char msg"
    dupe =
      Fabricate(
        :chat_message,
        created_at: 1.second.ago,
        message: message,
        chat_channel: chat_channel,
      )
    expect(message_blocked?(message)).to eq(true)

    expect(message_blocked?("blah")).to eq(false)

    dupe.update!(created_at: 61.seconds.ago)
    expect(message_blocked?(message)).to eq(false)
  end

  describe "#sensitivity_matrix" do
    describe "#min_user_count" do
      it "calculates correctly for each of the major points from 0.1 to 1.0" do
        expect(described_class.sensitivity_matrix(0.1)[:min_user_count]).to eq(100)
        expect(described_class.sensitivity_matrix(0.2)[:min_user_count]).to eq(89)
        expect(described_class.sensitivity_matrix(0.3)[:min_user_count]).to eq(78)
        expect(described_class.sensitivity_matrix(0.4)[:min_user_count]).to eq(68)
        expect(described_class.sensitivity_matrix(0.5)[:min_user_count]).to eq(57)
        expect(described_class.sensitivity_matrix(0.6)[:min_user_count]).to eq(47)
        expect(described_class.sensitivity_matrix(0.7)[:min_user_count]).to eq(36)
        expect(described_class.sensitivity_matrix(0.8)[:min_user_count]).to eq(26)
        expect(described_class.sensitivity_matrix(0.9)[:min_user_count]).to eq(15)
        expect(described_class.sensitivity_matrix(1.0)[:min_user_count]).to eq(5)
      end
    end

    describe "#min_message_length" do
      it "calculates correctly for each of the major points from 0.1 to 1.0" do
        expect(described_class.sensitivity_matrix(0.1)[:min_message_length]).to eq(30)
        expect(described_class.sensitivity_matrix(0.2)[:min_message_length]).to eq(27)
        expect(described_class.sensitivity_matrix(0.3)[:min_message_length]).to eq(25)
        expect(described_class.sensitivity_matrix(0.4)[:min_message_length]).to eq(23)
        expect(described_class.sensitivity_matrix(0.5)[:min_message_length]).to eq(21)
        expect(described_class.sensitivity_matrix(0.6)[:min_message_length]).to eq(18)
        expect(described_class.sensitivity_matrix(0.7)[:min_message_length]).to eq(16)
        expect(described_class.sensitivity_matrix(0.8)[:min_message_length]).to eq(14)
        expect(described_class.sensitivity_matrix(0.9)[:min_message_length]).to eq(12)
        expect(described_class.sensitivity_matrix(1.0)[:min_message_length]).to eq(10)
      end
    end

    describe "#min_past_seconds" do
      it "calculates correctly for each of the major points from 0.1 to 1.0" do
        expect(described_class.sensitivity_matrix(0.1)[:min_past_seconds]).to eq(10)
        expect(described_class.sensitivity_matrix(0.2)[:min_past_seconds]).to eq(15)
        expect(described_class.sensitivity_matrix(0.3)[:min_past_seconds]).to eq(21)
        expect(described_class.sensitivity_matrix(0.4)[:min_past_seconds]).to eq(26)
        expect(described_class.sensitivity_matrix(0.5)[:min_past_seconds]).to eq(32)
        expect(described_class.sensitivity_matrix(0.6)[:min_past_seconds]).to eq(37)
        expect(described_class.sensitivity_matrix(0.7)[:min_past_seconds]).to eq(43)
        expect(described_class.sensitivity_matrix(0.8)[:min_past_seconds]).to eq(48)
        expect(described_class.sensitivity_matrix(0.9)[:min_past_seconds]).to eq(54)
        expect(described_class.sensitivity_matrix(1.0)[:min_past_seconds]).to eq(60)
      end
    end
  end
end
