# frozen_string_literal: true

RSpec.describe Chat::DirectMessageChannel do
  subject(:channel) { Fabricate.build(:direct_message_channel) }

  it_behaves_like "a chat channel model"

  it { is_expected.to delegate_method(:allowed_user_ids).to(:direct_message).as(:user_ids) }

  describe "#category_channel?" do
    it "always returns false" do
      expect(channel).not_to be_a_category_channel
    end
  end

  describe "#public_channel?" do
    it "always returns false" do
      expect(channel).not_to be_a_public_channel
    end
  end

  describe "#chatable_has_custom_fields?" do
    it "always returns false" do
      expect(channel).not_to be_a_chatable_has_custom_fields
    end
  end

  describe "#direct_message_channel?" do
    it "always returns true" do
      expect(channel).to be_a_direct_message_channel
    end
  end

  describe "#read_restricted?" do
    it "always returns true" do
      expect(channel).to be_read_restricted
    end
  end

  describe "#allowed_group_ids" do
    it "always returns nothing" do
      expect(channel.allowed_group_ids).to be_nil
    end
  end

  describe "#chatable_url" do
    it "always returns nothing" do
      expect(channel.chatable_url).to be_nil
    end
  end

  describe "#title" do
    subject(:title) { channel.title(user) }

    let(:user) { stub }
    let(:direct_message) { channel.direct_message }

    it "delegates to direct_message" do
      direct_message.expects(:chat_channel_title_for_user).with(channel, user).returns("something")
      expect(title).to eq("something")
    end
  end

  describe "slug generation" do
    subject(:channel) { Fabricate(:direct_message_channel) }

    it "always sets the slug to nil for direct message channels" do
      channel.name = "Cool Channel"
      channel.validate!
      expect(channel.slug).to eq(nil)
    end
  end
end
