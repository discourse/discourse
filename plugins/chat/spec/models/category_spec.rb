# frozen_string_literal: true

RSpec.describe Category do
  it_behaves_like "a chatable model" do
    fab!(:chatable) { Fabricate(:category) }
    let(:channel_class) { Chat::CategoryChannel }
  end

  it { is_expected.to have_one(:category_channel).dependent(:destroy) }

  describe "#cannot_delete_reason" do
    subject(:reason) { category.cannot_delete_reason }

    context "when a chat channel is present" do
      let(:channel) { Fabricate(:category_channel) }
      let(:category) { channel.chatable }

      it "returns a message" do
        expect(reason).to match I18n.t("category.cannot_delete.has_chat_channels")
      end
    end
  end

  describe "#deletable_for_chat?" do
    subject(:category) { Fabricate.build(:category) }

    context "when no category channel is present" do
      it "returns true" do
        expect(category).to be_deletable_for_chat
      end
    end

    context "when a category channel is present" do
      let(:channel) { Fabricate(:category_channel) }
      let(:category) { channel.chatable }

      context "when it has chat messages" do
        before { Fabricate(:chat_message, chat_channel: channel) }

        it "returns false" do
          expect(category).not_to be_deletable_for_chat
        end
      end

      context "when it has no chat messages" do
        it "returns true" do
          expect(category).to be_deletable_for_chat
        end
      end
    end
  end
end
