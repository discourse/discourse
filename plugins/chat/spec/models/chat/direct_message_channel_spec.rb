# frozen_string_literal: true

RSpec.describe Chat::DirectMessageChannel do
  subject(:channel) { Fabricate.build(:direct_message_channel) }

  it_behaves_like "a chat channel model"

  it { is_expected.to delegate_method(:allowed_user_ids).to(:direct_message).as(:user_ids) }
  it { is_expected.to delegate_method(:group?).to(:direct_message).with_prefix.allow_nil }
  it { is_expected.to validate_length_of(:description).is_at_most(500) }
  it { is_expected.to validate_length_of(:chatable_type).is_at_most(100) }
  it { is_expected.to validate_length_of(:type).is_at_most(100) }

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

  describe "#threading_enabled" do
    it "defaults to true" do
      expect(channel.threading_enabled).to be(true)
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

  describe "#leave" do
    subject(:leave) { channel.leave(user) }

    let(:channel) { Fabricate(:direct_message_channel, group:) }
    let(:user) { channel.chatable.users.first }
    let(:membership) { channel.membership_for(user) }

    context "when DM is not a group" do
      let(:group) { false }

      it "unfollows the channel for the provided user" do
        expect { leave }.to change { membership.reload.following? }.to(false)
      end
    end

    context "when DM is a group" do
      let(:group) { true }

      it "destroys the provided user’s membership" do
        expect { leave }.to change { channel.user_chat_channel_memberships.where(user:).count }.by(
          -1,
        )
      end

      it "removes the provided user from the DM" do
        expect { leave }.to change { channel.chatable.users.where(id: user).count }.by(-1)
      end
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
