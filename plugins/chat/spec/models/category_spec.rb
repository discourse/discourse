# frozen_string_literal: true

require "rails_helper"

RSpec.describe Category do
  it_behaves_like "a chatable model" do
    fab!(:chatable) { Fabricate(:category) }
    let(:channel_class) { CategoryChannel }
  end

  it { is_expected.to have_one(:category_channel) }

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
end
